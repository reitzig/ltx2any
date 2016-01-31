# Copyright 2010-2016, Raphael Reitzig
# <code@verrech.net>
#
# This file is part of ltx2any.
#
# ltx2any is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ltx2any is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ltx2any. If not, see <http://www.gnu.org/licenses/>.

require "#{File.dirname(__FILE__)}/LogMessage.rb"

DependencyManager.add("xelatex", :binary, :recommended, "for PDF logs")

ParameterManager.instance.addParameter(Parameter.new(
  :logformat, "lf", [:raw, :md, :latex, :pdf], :md,
  "Set to 'raw' for raw, 'md' for Markdown, 'latex' for LaTeX, or 'pdf' for PDF log."))
ParameterManager.instance.addParameter(Parameter.new(
  :loglevel, "ll", [:error, :warning, :info], :warning,
  "Set to 'error' to see only errors, to 'warning' to see also warnings, or to 'info' for everything."))

# TODO If we get into trouble with Markdown fallback, this makes the dependencies mandatory:
#ParameterManager.instance.addHook(:logformat) { |key, val|
#  if ( val == :pdf )
#    DependencyManager.make_essential("xelatex", :binary)
#  end
#}

class Log 
  def initialize
    @messages = {}
    @counts = { :error => {:total => 0}, 
                :warning => {:total => 0},
                :info => {:total => 0}
              }
    @level = :warning # or :error, :info
    @rawoffsets = nil
    @mode = :structured # or :flat
  end
  
  def only_level(level = @level)  
    # Write messages from engine first
    # (Since @messages contains only one entry per run engine/extension, this is fast.)
    keys = @messages.keys.select { |k| @messages[k][0] == :engine } + 
           @messages.keys.select { |k| @messages[k][0] == :extension }

    # TODO rewrite for efficiency: this should give an iterator without
    #      actually doing anything.
    keys.map { |k|
      msgs = @messages[k][1].select { |m| 
        m.type == :error || # always show errors
        level == :info   || # show everything at info level
        level == m.type     # remaining case (warnings in :warning level)                           
      } 

      {k => [@messages[k][0], msgs, @messages[k][2]]  }
    }.reduce({}) { |res, e| res.merge!(e) }
  end
  
  public
    attr_accessor :level # TODO implement flat mode?
    
    # Parameters
    #  1. name of the source component (extension or engine)
    #  2. :engine or :extension
    #  3. List of LogMessage objects
    #  4. Raw log/output
    def add_messages(source, sourcetype, msgs, raw)
      if ( !@messages.has_key?(source) )
        @messages[source] = [sourcetype, [], ""]
        @counts[:error][source] = 0
        @counts[:warning][source] = 0
        @counts[:info][source] = 0
      end  

      @messages[source][1] += msgs
      @messages[source][2] += "#{raw}"
      [:error, :warning, :info].each { |type|
        cnt = msgs.count { |e| e.type == type }
        @counts[type][source] += cnt
        @counts[type][:total] += cnt
      }
      
      @rawoffsets = nil
    end
    
    def has_messages?(source)
      return @messages.has_key?(source)
    end
    
    def messages(source)
      return @messages[source].clone
    end
    
    def empty?
      return @messages.empty?
    end
    
    def count(type)
      return @counts[type][:total]
    end

    # Creates a Markdown-formatted log file at the specified location.
    # Returns the generated code
    # TODO why return? Relict from using it in to_pdf?
    def to_md(target_file = nil )
      # TODO it should be possible to determine offsets without any file I/O
      to_s if @rawoffsets == nil # Determines offsets in raw log
      params = ParameterManager.instance
    
      result = "# Log for `#{params[:jobname]}`\n\n"
      messages = only_level
      
      result << "**Disclaimer:**  \nThis is  but a digest of the original log file.\n" +
                "For full detail, check out `#{params[:tmpdir]}/#{params[:log]}.raw`.\n" +
                "In case we failed to pick up an error or warning, please " +
                "[report it to us](https://github.com/akerbos/ltx2any/issues/new).\n\n" 
      
      result << "We found **#{count(:error)} error#{pls(count(:error))}**, " +
                          "*#{count(:warning)} warning#{pls(count(:warning))}* " +
                       "and #{count(:info)} other message#{pls(count(:info))} in total.\n\n"
                       
      # Write everything
      messages.keys.each { |name|
        msgs = messages[name][1]
        
        result << "## `#{name}`\n\n"
        
        if ( msgs.empty? )
          result << "Lucky you, `#{name}` had nothing to complain about!\n\n"
          
          if ( (@level == :warning && @counts[:info][name] > 0) ||
               (@level == :error && @counts[:info][name] + @counts[:warning][name] > 0 ) )
            if ( @level != :info ) 
              result << "Note, though, that this log only lists errors"
              if ( @level == :warning )
                result << " and warnings"
              end
              result << ". There were "
              if ( @level == :error )
                result << "#{@counts[:warning][name]} warning#{pls(@counts[:warning][name])} and "
              end
              result << "#{@counts[:info][name]} information message#{pls(@counts[:info][name])} " +
                        "which you find in the full log.\n\n"
            end
          end
        else
          result << "**#{@counts[:error][name]} error#{pls(@counts[:error][name])}**, " +
                     "*#{@counts[:warning][name]} warning#{pls(@counts[:warning][name])}* " +
                "and #{@counts[:info][name]} other message#{pls(@counts[:info][name])}\n\n"
        
          msgs.each { |m|
            # Lay out for 80 characters width
            #  * 4 colums for list stuff
            #  * 11 columns for type + space
            #  * file:line flushed to the right after
            #  * The message, indented to the type stands out
            #  * Log line, flushed right
            result << " *  " +
                      { :error   => "**Error**",
                        :warning => "*Warning*",
                        :info    => "Info     "
                      }[m.type]
            if ( m.srcfile != nil ) 
              srcline = nil
              if ( m.srcline != nil )
                srcline = m.srcline.join("--")
              end
              srcfilelength = 76 - 9 - (if ( srcline != nil ) then srcline.length + 1 else 0 end) - 2
              result << if ( m.srcfile.length > srcfilelength )
                          "  `...#{m.srcfile[m.srcfile.length - srcfilelength + 5, m.srcfile.length]}"
                        else
                          (" " * (srcfilelength - m.srcfile.length)) + "`#{m.srcfile}" 
                        end
              if ( srcline != nil )
                result << ":#{srcline}"
              end
              result << "`"
            end
            result << "\n\n"
            if ( m.formatted? )
              result << indent(m.msg.strip, 8) + "\n\n"
            else
              result << break_at_spaces(m.msg.strip, 68, 8) + "\n\n"
            end
            if ( m.logline != nil )
              # We have line offset in the raw log!
              logline = m.logline.map { |i| i += @rawoffsets[name] }.join("--")
              result << (" " * (80 - (6 + logline.length))) + "`log:" + logline + "`\n\n\n"
            end
          }
        end
      }
      
      if ( target_file != nil )
        File.open("#{target_file}", "w") { |f| f.write(result) }
      end
      return result
    end

    # Creates a LaTeX document containing all messages at the specified location.
    def to_latex(target_file = "#{ParameterManager.instance[:jobname]}.log.tex")
      to_s if @rawoffsets == nil # Determines offsets in raw log
      params = ParameterManager.instance

      File.open(target_file, "w") { |f|
        # Copy template
        File.open("#{File.dirname(__FILE__)}/logtemplate.tex", "r") { |template|
          f.write(template.read)
        }
        f.write("\\def\\author{ltx2any}\n\\def\\title{Log for #{params[:jobname]}}\n")
        f.write("\\def\\fulllog{#{params[:tmpdir]}/#{params[:log]}.raw}\n")
        f.write("\n\n\\begin{document}")

        f.write("\\section{Log for \\texttt{#{params[:jobname]}}}\n\n")
        messages = only_level
        
        f.write("\\textbf{Disclaimer:} This is  but a digest of the original log file. " +
                  "For full detail, check out \\loglink. " +
                  "In case we failed to pick up an error or warning, please " +
                  "\\href{https://github.com/akerbos/ltx2any/issues/new}{report it to us}.\n\n")
        
        f.write("We found \\errlink{\\textbf{#{count(:error)}~error#{pls(count(:error))}}}, " +
                          "\\textsl{#{count(:warning)}~warning#{pls(count(:warning))}} " +
                          "and #{count(:info)}~other message#{pls(count(:info))} in total.\n\n")
                         
        # Write everything
        messages.keys.each { |name|
          # We get one block per tool that ran
          msgs = messages[name][1]
        
          f.write("\\subsection{\\texttt{#{name}}}\n\n")
          
          if ( msgs.empty? )
            f.write("Lucky you, \\texttt{#{name}} had nothing to complain about!\n\n")
          else 
            f.write("\n\\begin{itemize}\n")

            msgs.each { |m|
              f.write("\n\n\\item\\blockitem\n")
              
              # Write the error type and source file reference
              if m.type == :error && params[:loglevel] != :error
                f.write("\\linkederror{")
              else
                f.write("\\#{m.type.to_s}{")
              end
              
              srcline = m.srcline || ["",""]
              srcline.push("") if srcline.length < 2
              f.write("#{makeFileref(m.srcfile, srcline[0], srcline[1])}}\n\n")
              
              # Write the log message itself
              f.write("\\begin{verbatim}\n")
              if ( m.formatted? )
                f.write(indent(m.msg.strip, 0))
              else
                f.write(break_at_spaces(m.msg.strip, 68, 1))
              end
              f.write("\n\\end{verbatim}")
              
              # Write the raw log reference
              if ( m.logline != nil )
                # We have line offsets in the raw log!
                logline = m.logline.map { |i| i += @rawoffsets[name] }
                logline.push("") if logline.length < 2
                f.write("\n\n\\logref{#{logline[0]}}{#{logline[1]}}")
              end
              
              f.write("\n\\endblockitem\n\n")
            }
            
            f.write("\n\\end{itemize}")
          end
        }
        
        f.write("\n\n\\end{document}")
      }
    end

    # Creates a PDF containing all messages (depending on log level) at the specified location.
    def to_pdf(target_file = "#{ParameterManager.instance[:jobname]}.log.pdf")
      if ( !DependencyManager.available?('xelatex', :binary)  )
        raise "You need xelatex for PDF logs."
      end
      params = ParameterManager.instance

      tmplogprefix = "#{ParameterManager.instance[:jobname]}.log."
      to_latex("#{tmplogprefix}tex")

      # TODO which engine to use?
      xelatex = '"xelatex -file-line-error -interaction=nonstopmode \"#{tmplogprefix}tex\""'
      IO::popen(eval(xelatex)) { |x| x.readlines }
      # TODO parse log and rewrite a readable version?
      
      if !File.exist?("#{tmplogprefix}pdf")
        # This should never happen!
        msg = "Log failed to compile!"
        if ( params[:daemon] || !params[:clean] )
          msg += " See #{params[:tmpdir]}/#{tmplogprefix}log."
        end
        raise msg
      elsif "#{tmplogprefix}pdf" != target_file
        FileUtils::cp("#{tmplogprefix}pdf", target_file)
      end
    end

    # Creates a raw log file containing all messages (depending on log level)
    # at the specified location.
    # Returns the resulting string.
    def to_s(target_file = nil)
      result = ""
      messages = only_level(:info)      
      
      offset = 0
      @rawoffsets = {}
      messages.keys.each { |source|
        result << "# # # # #\n"
        result << "# Start #{source}"
        result << "\n# # # # #\n\n"
        
        @rawoffsets[source] = offset + 4
        result << messages[source][2]
        
        result << "\n\n# # # # #\n"
        result << "# Finished #{source}"
        result << "\n# # # # #\n\n"
        
        offset += 10 + messages[source][2].count(?\n)
      }
       
      if ( target_file != nil )
        File.open("#{target_file}", "w") { |f| f.write(result) }
      end
      return result
    end
    
    def self.fix(s)
      # Prevents errors when engines write illegal symbols to log.
      # Since the API changed between Ruby 1.8.x and 1.9, be
      # careful.
      RUBY_VERSION.to_f < 1.9 ? 
        Iconv.iconv('UTF-8//IGNORE', 'UTF-8',  s) :
        s.encode!(Encoding::UTF_16LE, :invalid => :replace, 
                                      :undef => :replace, 
                                      :replace => '?').encode!(Encoding::UTF_8)
    end
    
    private 
      def break_at_spaces(s, length, indent)
        words = s.split(/\s+/)

        res = ""
        line = " " * [0, indent - 1].max
        words.each { |w|
          newline = line + " " + w
          if ( newline.length > length )
            res += line + "\n"
            line = (" " * indent) + w
          else
            line = newline
          end
        }
        
        return res + line
      end
      
      def indent(s, indent)
        s.split("\n").map { |line| (" " * indent) + line }.join("\n")
      end
      
      def pls(count)
        if ( count == 1 )
          ""
        else
          "s"
        end
      end

      def makeFileref(file, linefrom, lineto)
        fileref = ""
        if ( file != nil )
          filename = file.gsub(/_/, '\_')
          fileref = "\\fileref{#{filename}}{#{linefrom}}{#{lineto}}"
        end
        fileref
      end
end
