# Copyright 2010-2015, Raphael Reitzig
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

class Output
  def initialize(name)
    @shortcode = "[#{name}]"
    @success   = "Done"
    @error     = "Error"
    @cancel    = "Cancelled"
  end

  private
    def puts_indented(msgs)
      msgs.each { |m|
        puts "#{" " * @shortcode.length} #{m}"
      }
    end

  public
    def msg(*msg)
      if ( msg.size > 0 )
        puts "#{@shortcode} #{msg[0]}"
        if ( msg.length > 1 )
          puts_indented(msg.drop(1))
        end
      end
      STDOUT.flush
    end
    
    def start(msg)
      print "#{@shortcode} #{msg} ... "
      STDOUT.flush
    end
    
    def stop(state, *msg)
      puts instance_variable_get(("@#{state}").intern).to_s
      puts_indented(msg)
      STDOUT.flush
    end
    
    def separate
      puts ""
      return self
    end
end
