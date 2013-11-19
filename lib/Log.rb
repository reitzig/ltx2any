# Copyright 2010-2013, Raphael Reitzig
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

class Log
  def initialize(params)
    @messages = {}
    @counts = { :error => {:total => 0}, 
                :warning => {:total => 0},
                :info => {:total => 0}
              }
    @level = :warning # or :error, :info
    @rawoffsets = nil
    @mode = :structured # or :flat
    @dependencies = [["pandoc", :binary, if ( params[:logformat] == :pdf ) 
                                         then :essential
                                         else :recommended end], 
                     ["pdflatex", :binary, if ( params[:logformat] == :pdf ) 
                                           then :essential
                                           else :recommended end]]
    @params = params
  end
  
  def only_level(level = @level)
    # Write messages from engine first
    keys = @messages.keys.select { |k| @messages[k][0] == :engine } + 
           @messages.keys.select { |k| @messages[k][0] == :extension }
             
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
    
    def to_md(target_file = nil )
      if ( @rawoffsets == nil ) 
        to_s # Determines offsets in raw log
      end
    
      result = "# Log for `#{@params[:jobname]}`\n\n"
      messages = only_level
      
      result << "**Disclaimer:**  \nThis is  but a digest of the original log file.\n" +
                "For full detail, check out `#{@params[:tmpdir]}/#{@params[:log]}.raw`.\n" +
                "In case we failed to pick up an error or warning, please " +
                "[report it to us](https://github.com/akerbos/ltx2any/issues/new).\n\n" 
      # TODO get rid of ugly dependency on globals and code cross-dep.
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
    
    def to_pdf(target_file = "#{@params[:jobname]}.log.pdf") # TODO once central binary check is there, remove these.
      if ( `which pandoc` == "" )
        raise "You need pandoc for PDF logs."
      end
      if ( `which pdflatex` == "" )
        raise "You need pdflatex for PDF logs."
      end
            
      template = "#{File.dirname(__FILE__)}/logtemplate.tex"
      pandoc = '"pandoc -f markdown --template=\"#{template}\" -V papersize:a4paper -V geometry:margin=3cm -V fulllog:\"#{@params[:tmpdir]}/#{@params[:log]}.raw\" -o \"#{target_file}\" 2>&1"' 

      panout = IO::popen(eval(pandoc), "w+") { |f|
        markdown = to_md
        
        # Perform some cosmetic tweaks and add LaTeX hooks
        if ( @params[:loglevel] != :error )
          # When there are messages other than errors, provide error navigation
          markdown.gsub!(/(We found) \*\*(\d+ errors?)\*\*/, 
                         "\\1 \\errlink{\\textbf{\\2}}")
        end
        markdown.gsub!(/^ \*  \*\*Error\*\*(?:\s+`([^:`]*)(?::(\d+)(?:--(\d+))?)?`)?$/) { |match|
          # When there are messages other than errors, provide error navigation
          linked = if ( @params[:loglevel] != :error ) then "linked" else "" end
          " \*  \\blockitem\\#{linked}error#{makeFileref($1, $2, $3)}"
        } 
        markdown.gsub!(/^ \*  \*Warning\*(?:\s+`([^:`]*)(?::(\d+)(?:--(\d+))?)?`)?$/) { |match|
          " \*  \\blockitem\\warning#{makeFileref($1, $2, $3)}"
        }
        markdown.gsub!(/^ \*  Info(?:\s+`([^:`]*)(?::(\d+)(?:--(\d+))?)?`)?$/) { |match|
          " \*  \\blockitem\\info#{makeFileref($1, $2, $3)}"
        } 
        markdown.gsub!(/^\s+`log:(\d+)(?:--(\d+))?`$/,  "\\logref{\\1}{\\2}\\endblockitem")
        markdown.gsub!(/`#{@params[:tmpdir]}\/#{@params[:log]}.raw`/, "\\loglink")
      
        f.puts(markdown)
        f.close_write
        f.read
      }
      
      if ( panout.strip != "" )
        # That should never happen
        File.open("#{target_file}.log", "w") { |f| f.write(panout) }
        msg = "Pandoc encountered errors!"
        if ( @params[:daemon] || !@params[:clean] )
          msg += " See #{@params[:tmpdir]}/#{target_file}.log."
        end
        raise msg
      end
    end
    
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
        line = " " * (indent - 1)
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
