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

class TeXLogParser
  # Input: 
  #  * log -- string array (one entry per line)
  #  * startregexp -- start collecting messages after first match
  #                   Default: matches any line, thus collects from the start
  #  * endregexp   -- stop collecting at first match after collection started
  #                   Default: matches nothing, thus collects to the end
  # Output: Array of Message objects
  def self.parse(log, startregexp = /.*/, endregexp = /(?=a)b/)
    # Contains a stack of currently "open" files.
    # filestack.last is the current one.
    filestack = []
    
    # Result collection
    messages = []
        
    # The stack of files the log is currently "in"
    filestack = []
    
    collecting = false
    linectr = 1 # Declared for the increment at the end of the loop
    current = Finalizer.new
    log.each { |line|
      if ( !collecting && startregexp =~ line )
        collecting = true
        linectr = 1
      end
      if ( collecting && endregexp =~ line )
        messages += [current.get_msg].compact
        break
      end

      # Even when not collecting, we need to keep track of which file
      # we are in.
      if ( collecting && line.strip == "" )
       # Empty line ends messages
        messages += [current.get_msg].compact 
      elsif ( /^l\.(\d+) (.*)$/ =~ line )
        # Line starting with a line number ends messages
        if ( current.srcline == nil )
          current.srcline = [Integer($~[1])]
        end
        current.message += $~[2].strip
        current.logline[1] = linectr
        messages += [current.get_msg].compact 
      elsif ( /^(\([^()]*\)|[^()])*\)/ =~ line )
        # End of messages regarding current file
        if ( collecting )
          messages += [current.get_msg].compact
        end

        filestack.pop
        
        # Multiple files may close; cut away matching part and start over.
        line = line.gsub($~.regexp, "")
        redo
      elsif ( /^[^()]*(\([^()]*\).*?)*[^()]*\(([^()]*?(\(|$))/ =~ line )
        #       {                          }
        #       skip series of matching parens and gutter
        #                                   {        }
        #                                   opening paren and potential filename
        #
        # A new file has started. Match only those that don't close immediately.
        candidate = $~[2]
        
        while( !File.exist?(candidate) && candidate != "" ) do # TODO can be long; use heuristics?
          candidate = candidate[0,candidate.length - 1]
        end
        if ( File.exist?(candidate) )
          filestack.push(candidate)
        else 
          # Lest we break everything by false negatives (due to linebreaks), 
          # add a dummy and hope it closes.
          filestack.push("dummy")
        end

        # Multiple files may open; cut away matching part and start over.
        replace = if ( ["("].include?($~[3]) ) then $~[3] else "" end
        line = line.gsub($~.regexp, replace)
        redo
      elsif ( collecting ) # Do all the checks only when collecting
        if ( /^([\.\/\w\d]*?):(\d+): (.*)/ =~ line )
          messages += [current.get_msg].compact
          # messages.push(LogMessage.new(:error, $~[1], [Integer($~[2])], [linectr], $~[3].strip))
          
          current.type = :error
          current.srcfile = $~[1]
          current.srcline = [Integer($~[2])]
          current.logline = [linectr]
          current.message = $~[3].strip + "\n"
          current.slicer = nil
          current.format = :fixed
        elsif ( /(Package|Class)\s+([\w]+)\s+(Warning|Error|Info)/ =~ line )
          # Message from some package or class, may be multi-line
          messages += [current.get_msg].compact
          
          current.type = if ( $~[3] == "Warning" )
                         then :warning
                         elsif ( $~[3] == "Info" )
                         then :info
                         else :error 
                         end
          current.srcfile = filestack.last
          current.srcline = nil
          current.logline = [linectr]
          current.message = line.strip
          current.slicer = /^\(#{$~[2]}\)\s*/
        elsif ( /\w+?TeX\s+(Warning|Error|Info)/ =~ line )
          # Some message from the engine, may be multi-line
          messages += [current.get_msg].compact

          current.type = if ( $~[1] == "Warning" )
                         then :warning
                         elsif ( $~[1] == "Info" )
                         then :info 
                         else :error
                         end
          current.srcfile = filestack.last
          current.srcline = nil
          current.logline = [linectr]
          current.message = line.strip
          current.slicer = /^\s*/
        elsif ( /^((Under|Over)full .*?) at lines (\d+)--(\d+)?/ =~ line )
          # Engine complains about under-/overfilled boxes
          messages += [current.get_msg].compact

          fromLine = Integer($~[3])
          toLine = Integer($~[4])
          srcLine = [fromLine]
          if ( toLine >= fromLine )
            srcLine[1] = toLine
          else
            # This seems to happen for included files. The first number is the
            # line in the including file, the second in the included one.
            # TODO What for chains?
            srcLine = [toLine]
          end
            
          messages.push(LogMessage.new(:warning, filestack.last, srcLine, [linectr], $~[1].strip))
        elsif ( /^((Under|Over)full .*?)[\d\[\]]*$/ =~ line )
          messages += [current.get_msg].compact
          messages.push(LogMessage.new(:warning, filestack.last, nil, [linectr], $~[1].strip))
        elsif ( /^Runaway argument\?$/ =~ line )
          messages += [current.get_msg].compact
          current.type = :error
          current.srcfile = filestack.last
          current.srcline = nil
          current.logline = [linectr]
          current.message = line.strip + "\n"
          current.format = :fixed
        elsif ( current.type != nil )
          if ( current.slicer != nil )
            line = line.gsub(current.slicer, "")
          end
          if ( current.format != :fixed )
            line = " " + line.strip!
          end
          current.message += line
          current.logline[1] = linectr
        end
      end
         
      linectr += 1
    } 
   
    return messages
  end
  
  private
  
    # Some messages may run over multiple lines. Use an instance
    # of this class to collect it completely.
    class Finalizer
      def initialize
        reset
      end
      
      def reset
        @type = nil
        @srcfile = nil
        @srcline = nil
        @logline = nil
        @message = nil
        @format = :none
        
        @slicer = nil
      end 
      
      public
        attr_accessor :type, :srcfile, :srcline, :logline, :message, :format, :slicer
      
        #  (initially: @currentmessage = [nil, nil, nil, nil, nil, nil, :none] )
        def get_msg()
          if ( @type != nil )
            res = LogMessage.new(@type, @srcfile, @srcline, @logline, @message, @format)
            reset
            return res
          else
            reset
            return nil
          end
        end
    end
end
