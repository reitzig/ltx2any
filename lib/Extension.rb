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

class Extension  
  @@list = {}
  
  def self.add(e)
    @@list[e.to_sym] = e
  end

  def self.list
    return @@list.values
  end

  def self.[](key) 
    return @@list[key]
  end

  def self.to_sym
    self.new.to_sym
  end
 
  def initialize
    @name = "Dummy name"
    @description = "Dummy description"
  end

  # Hacky hack? Need to refactor this
  def self.name
    self.new.name
  end
  
  def self.description
    self.new.description
  end
  
  public
    def do?()
      false
    end
    
    def job_size
      return 1
    end

    def exec(progress)
      return [true, "No execution code, need to overwrite!"]
    end

    def to_s
      @name
    end

    def to_sym
      self.class.name.downcase.to_sym
    end
    
    attr_accessor :name, :description
    
  protected
    attr_reader :params
    attr_writer :name, :description
end
