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
             "\t(For details see full log from line #{@logline}.)"
    end
end
