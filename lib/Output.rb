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

require 'singleton'

Dependency.new('ruby-progressbar', :gem, [:core, 'Output'], :recommended, 'nice progress indicators', '>=1.7.5')

class Output
  include Singleton

  def initialize
    @success   = 'Done'
    @error     = 'Error'
    @warning   = 'Warning'
    @cancel    = 'Cancelled'
    @shortcode = "[#{NAME}]"
    @dependencies = DependencyManager.list(source: [:core, self.class.to_s])
    @running = false
    @pending = []
  end

  private
    def puts_indented(msgs)
      msgs.each { |m|
        puts "#{' ' * @shortcode.length} #{m}"
      }
    end

  public
    def msg(*msg)
      if !msg.empty? && !@running
        puts "#{@shortcode} #{msg[0]}"
        puts_indented(msg.drop(1)) if msg.size > 1
        STDOUT.flush
      elsif !msg.empty?
        # Store message to be printed after the current
        # process finished
        @pending << msg
      end
    end

    def warn(*msg)
      if msg.size > 0
        msg[0] = "#{@warning}: #{msg[0]}"
        msg(*msg)
      end
    end
    
    def error(*msg)
      if msg.size > 0
        msg[0] = "#{@error}: #{msg[0]}"
        msg(*msg)
      end
    end

    def start(msg, count=1)
      @running = true
      if count > 1 && @dependencies.all? { |d| d.available? }
        # Set up progress bar if needed
        require 'ruby-progressbar'
        progress = ProgressBar.create(:title => "#{@shortcode} #{msg} ...",
                                      :total => count,
                                      :format => '%t [%c/%C]',
                                      :autofinish => false)
        return [lambda { progress.increment },
                lambda { |state, *msgs|
                  progress.format("#{@shortcode} #{msg} ... #{instance_variable_get(("@#{state}").intern).to_s}" + (' ' * 5)) # Add some spaces to hide all for up to 999 steps
                  # TODO We *know* that we need 2*ceil(log_2(count)) - 1 spaces...
                  progress.stop
                  puts_indented(*msgs) if msgs.size > 0
                  STDOUT.flush
                  }]
      # TODO notify user of missing dependency?
      end
      
      # Fallback if progress bar not needed, or gem not available
      print "#{@shortcode} #{msg} ... "
      STDOUT.flush
      [lambda {}, lambda { |state, *msgs| stop(state, *msgs) }]
    end

    def stop(state, *msg)
      puts instance_variable_get(("@#{state}").intern).to_s
      puts_indented(msg) if msg.size > 0
      STDOUT.flush

      # Print messages that were held back during the process
      # that just finished.
      @running = false
      @pending.each { |msgs|
        msg(*msgs)
      }
      @pending.clear
    end

    def separate
      puts ''
      self
    end
end
