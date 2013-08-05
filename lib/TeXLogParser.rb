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

class TeXLogParser
  # Input: string array (one entry per line)
  # Output: Array of Message objects
  def self.parse(log)
    # Contains a stack of currently "open" files.
    # filestack.last is the current one.
    filestack = []
    
    # Result collection
    messages = []
        
    # The stack of files the log is currently "in"
    filestack = []
    
    linectr = 1
    @currentMessage = [nil, nil, nil, [nil,nil], nil, nil]
    log.each { |line|
      if ( line.strip == "" )
        messages += [finalizeMessage].compact
        
      elsif ( /^(\([^()]*\)|[^()])*\)/ =~ line )
        # End of messages regarding current file
        messages += [finalizeMessage].compact
        
        filestack.pop
        #puts "End " + (if filestack.empty? then "????" else filestack.pop end)
        #puts "Cur " + (if filestack.empty? then "????" else filestack.last end)
        
        # Multiple files may close; cut away matching part and start over.
        #puts "Original:\t#{line.strip}\n"
        line = line.gsub($~.regexp, "")
        #puts "New:\t\t#{line.strip}\n\n" # TODO remove debug stuff
        redo
      elsif ( /\(([^()]*?)(\s+\[\d+\]\s+)?$/ =~ line )
        # A new file has started
        candidate = $~[1]
        #puts "File? #{candidate}"
        while( !File.exist?(candidate) && candidate != "" ) do # TODO can be long; use heuristics?
          candidate = candidate[0,candidate.length - 1]
          #puts "File? #{candidate}"
        end
        if ( File.exist?(candidate) )
          filestack.push(candidate)
          #puts "Start #{candidate}"
        else # TODO remove debug stuff
        #  puts "Thought that was a file: #{$~[1]}"
          # Lest we break everything by false negatives (due to linebreaks), 
          # add a dummy and hope it closes.
          filestack.push("dummy")
          #puts "Start dummy"
        end
      elsif ( /(Package|Class)\s+([\w]+)\s+(Warning|Error|Info)/ =~ line )
        # Message from some package or class, may be multi-line
        messages += [finalizeMessage].compact
        
        @currentMessage[0] = if ( $~[3] == "Warning" )
                             then :warning
                             elsif ( $~[3] == "Info" )
                             then :info
                             else :error 
                             end
        @currentMessage[1] = filestack.last
        @currentMessage[2] = -1
        @currentMessage[3] = [linectr, linectr]
        @currentMessage[4] = line.strip
        @currentMessage[5] = /^\(#{$~[2]}\)\s*/
      elsif ( /\w+?TeX\s+(Warning|Error|Info)/ =~ line )
        # Some message from the engine, may be multi-line
        messages += [finalizeMessage].compact

        @currentMessage[0] = if ( $~[1] == "Warning" )
                             then :warning
                             elsif ( $~[1] == "Info" )
                             then :info 
                             else :error
                             end
        @currentMessage[1] = filestack.last
        @currentMessage[2] = -1
        @currentMessage[3] = [linectr, linectr]
        @currentMessage[4] = line.strip
        @currentMessage[5] = /^\s*/
      elsif ( /(Under|Over)full .*? (\d+--\d+)/ =~ line )
        # Engine complains about under-/overfilled boxes
        messages += [finalizeMessage].compact
        
        messages.push(Message.new(:warning, filestack.last, $~[2], linectr, line.strip))
      elsif ( !filestack.empty? && /^#{Regexp.escape(filestack.last)}:(\d+): (.*)/ =~ line )
        messages += [finalizeMessage].compact
        
        messages.push(Message.new(:error, filestack.last, $~[1], linectr, line.strip))
        # TODO is it worthwhile to try and copy the context?
      elsif ( @currentMessage[0] != nil )
        if (@currentMessage[5] != nil )
          line = line.gsub(@currentMessage[5], "")
        end
        @currentMessage[4] += " #{line.strip}"
        @currentMessage[3][1] = linectr
      #else
      #  puts line.strip
      end
         
      linectr += 1
    } 
   
    return messages
  end
  
  # Some messages may run over multiple lines. Complete with this:
  #  (initially: @currentmessage = [nil, nil, [nil,nil], nil, nil] )
  def self.finalizeMessage()
    if ( @currentMessage[0] != nil )
      res = 
        Message.new(@currentMessage[0], # type
                    @currentMessage[1], # srcfile
                    @currentMessage[2], # srcline
                    "#{@currentMessage[3][0]}--#{@currentMessage[3][1]}", # logline
                    @currentMessage[4] # message
                   )
      @currentMessage = [nil, nil, nil, [nil,nil], nil, nil]
      return res
    else
      return nil
    end
  end
end

class Message
  # Parameter type: one of :error, :warning, :info
  # Parameter srcfile: name of the source file the message originated at
  # Parameter srcline: line in the given file the message originated at 
  #                    -1 if not available
  # Parameter logline: line(s) in the log the message was found at
  # Parameter msg: String describing the problem
  def initialize(type, srcfile, srcline, logline, msg)
    @type = type
    @srcfile = srcfile
    @srcline = srcline
    @logline = logline
    @msg = msg
  end
  
  public
    attr_reader :type, :srcfile, :srcline, :logline, :msg
    
    def to_s
      return (if ( @type == :warning ) then "Warning" 
              elsif ( @type == :error ) then "Error"
              else "Info" end) +
             " #{@srcfile}:#{@srcline}\n" +
             @msg + "\n" +
             "(See full log at lines #{@logline}.)"
    end
end
