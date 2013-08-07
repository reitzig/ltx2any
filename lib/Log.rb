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

require '../lib/LogMessage.rb'

class Log
  def initialize(jobname)
    @messages = {}
    @counts = { :error => {:total => 0}, 
                :warning => {:total => 0},
                :info => {:total => 0}
              }
    @jobname = jobname
    @level = :warning # or :error, :info
    @mode = :structured # or :flat
    @dependencies = [["pandoc", :binary, if ( $params['logformat'] == :pdf ) 
                                         then :essential
                                         else :recommended end], 
                     ["pdflatex", :binary, if ( $params['logformat'] == :pdf ) 
                                           then :essential
                                           else :recommended end]]
  end
  
  def only_level(level = @level)
    @messages.keys.map { |k|
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
      @messages[source][2] += "\n\n#{raw}"
      [:error, :warning, :info].each { |type|
        cnt = msgs.count { |e| e.type == type }
        @counts[type][source] += cnt
        @counts[type][:total] += cnt
      }
    end
    
    def empty?
      return @messages.empty?
    end
    
    def count(type)
      return @counts[type][:total]
    end
    
    def to_md(target_file = "#{@jobname}.log.md" )
      result = "# Log for `#{@jobname}`\n\n"
      messages = only_level
      
      result << "**Disclaimer:**  \nThis is  but a digest of the original log file.  \n" +
                "For full detail, check out `#{$params['tmpdir']}/#{@jobname}.log.raw`.\n\n" 
      
      result << "We found **#{count(:error)} errors**, *#{count(:warning)} warnings* " +
                "and #{count(:info)} other messages in total.\n\n"
      
      # Write messages from engine first
      keys = messages.keys.select { |k| messages[k][0] == :engine } + 
             messages.keys.select { |k| messages[k][0] == :extension }
      
      # Write everything
      keys.each { |name|
        msgs = messages[name][1]
        
        result << "## `#{name}`\n\n"
        
        if ( msgs.empty? )
          result << "Lucky you, `#{name}` had nothing to complain about!\n\n"
          
          if ( @level != :info ) 
            result << "Note, though, that this log only lists errors"
            if ( @level == :warning )
              result << " and warnings"
            end
            result << ". There were "
            if ( @level == :error )
              result << "#{@counts[:warning][name]} warnings and "
            end
            result << "#{@counts[:info][name]} information messages which you find in the full log.\n\n"
          end
        else
          result << "**#{@counts[:error][name]} errors**, *#{@counts[:warning][name]} warnings* " +
                "and #{@counts[:info][name]} other messages\n\n"
        
          msgs.each { |m|
            # Lay out for 80 characters width
            #  * 4 colums for list stuff
            #  * 11 columns for type + space
            #  * file:line flushed to the right after
            #  * The message, indented to the type stands out
            #  * Log line, flushed right
            result << " *  " +
                      { :error   => "**Error**  ",
                        :warning => "*Warning*  ",
                        :info    => "Info       "
                      }[m.type]
            srcfilelength = 76 - 11 - m.srcline.to_s.length - 3
            result << if ( m.srcfile.length > srcfilelength )
                        "`...#{m.srcfile[m.srcfile.length - srcfilelength - 3, m.srcfile[m.srcfile.length]]} "
                      else
                        (" " * (srcfilelength - m.srcfile.length)) + "`#{m.srcfile}" 
                      end
            result << ":#{m.srcline.to_s}`\n\n"
            result << break_at_spaces(m.msg.strip, 68, 8) + "\n\n"
            result << (" " * (80 - (5 + m.logline.to_s.length))) + "log: " + m.logline.to_s + "\n\n"
          }
        end
      }
      
      File.open("#{target_file}", "w") { |f| f.write(result) }
      return result
    end
    
    def to_pdf(target_file = "#{@jobname}.log.pdf")
      if ( `which pandoc` == "" )
        raise "You need pandoc for PDF logs."
      end
      if ( `which pdflatex` == "" )
        raise "You need pdflatex for PDF logs."
      end
            
      template = "#{File.dirname(__FILE__)}/logtemplate.tex"
      pandoc = '"pandoc -f markdown --template=\"#{template}\" -V papersize:a4paper -V geometry:margin=3cm -o \"#{target_file}\" 2>&1"' 

      panout = IO::popen(eval(pandoc), "w+") { |f|
        markdown = to_md
        
        # Perform some cosmetic tweaks
        markdown.gsub!(/^ \*  \*\*Error\*\*/, " \*  \\error")
        markdown.gsub!(/^ \*  \*Warning\*/, " \*  \\warning")
        markdown.gsub!(/^ \*  Info/, " \*  \\info")
        markdown.gsub!(/^\s+log: (\d+(--\d+)?)$/,  "\\logref{\\1}")
      
        f.puts(markdown)
        f.close_write
        f.read
      }
      
      if ( panout.strip != "" )
        # That should never happen
        File.open("#{target_file}.log", w) { |f| f.write(panout) }
        raise "Pandoc encountered errors! See #{target_file}.log."
      end
    end
    
    def to_s(target_file = "#{@jobname}.log", raw = false) # TODO add machine-readable mode?
      result = ""
      messages = only_level      
      
      if ( raw )
        messages.keys.each { |source|
          result << "# # # # #\n"
          result << "# Start #{source}"
          result << "\n# # # # #\n\n"
          
          result << messages[source][2]
          
          result << "# # # # #\n"
          result << "# Finished #{source}"
          result << "\n# # # # #\n\n"
        }
      else
        result << "Disclaimer: This is a digest of the original log file.\n" +
                  "            For full detail, check out #{@jobname}.log.raw.\n\n" 
                  
        result << "We found #{count(:error)} errors, #{count(:warning)} warnings " +
                "and #{count(:info)} other messages in total.\n\n"
        
        messages.keys.each { |source|
          result << "# # # # #\n"
          result << "# Start #{source}"
          result << "\n# # # # #\n\n"
          
          messages[source][1].each { |msg|
            result << "#{msg.to_s}\n\n"
          }
          
          result << "# # # # #\n"
          result << "# Finished #{source}"
          result << "\n# # # # #\n\n"
        }
      end
       
      File.open("#{target_file}", "w") { |f| f.write(result) }
      return result
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
end
