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

class LogMessage
  def self.dependencies
    return []
  end
  
  # Parameter type: one of :error, :warning, :info
  # Parameter srcfile: name of the source file the message originated at
  #                    nil if not available
  # Parameter srcline: lines in the given file the message originated at
  #                    as array of integers [line] or [from,to]. 
  #                    nil if not available
  # Parameter logline: line(s) in the log the message was found at as array
  #                    of integers [line] or [from,to].
  #                    nil if that does not make sense.
  # Parameter msg: String describing the problem
  # Parameter format: pass :fixed if you don't want the format of the message
  #                   changed for output.
  def initialize(type, srcfile, srcline, logline, msg, format = :none)
    @type = type
    @srcfile = srcfile
    @srcline = srcline
    @logline = logline
    @msg = msg
    @format = format
  end
  
  public
    attr_reader :type, :srcfile, :srcline, :logline, :msg
    
    def to_s
      result = (if ( @type == :warning ) then "Warning" 
                elsif ( @type == :error ) then "Error"
                else "Info" end) 
              
      if ( @srcfile != nil )
        result += " #{@srcfile}"
        if ( @srcline != nil )
          result += ":#{@srcline.join("-")}"
        end
      end
      
      result += "\n" + @msg
      
      if ( @logline != nil )
        result +="\n\t(For details see original output from line #{@logline[0].to_s}.)"
      end
      return result
    end
    
    def formatted?
      @format == :fixed
    end
end
