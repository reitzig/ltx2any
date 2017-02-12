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

class Log 
  def initialize
    @messages = {}
    @counts = { :error => {:total => 0}, 
                :warning => {:total => 0},
                :info => {:total => 0}
              }
    #@level = :warning # or :error, :info
    @rawoffsets = nil
    @mode = :structured # or :flat
    @dependencies = DependencyManager.list(source: [:core, self.class.to_s])
  end
  
  def only_level(level)
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
    attr_reader :rawoffsets # TODO implement differently?
    
    # Parameters
    #  1. name of the source component (extension or engine)
    #  2. :engine or :extension
    #  3. List of LogMessage objects
    #  4. Raw log/output
    def add_messages(source, sourcetype, msgs, raw)
      if !@messages.has_key?(source)
        @messages[source] = [sourcetype, [], '']
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
      @messages.has_key?(source)
    end
    
    def messages(source)
      @messages[source].clone
    end
    
    def empty?
      @messages.empty?
    end
    
    def count(type, part = :total)
      @counts[type][part]
    end

    # Creates a string with the raw log messages.
    def to_s
      # TODO it should be possible to determine offsets without building the log
      result = ''
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

      result
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
end
