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

class Engine
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

  # Hacky hack? Need to refactor this
  def self.description
    self.new.description
  end

  def self.binary
    self.new.binary
  end

  def self.extension
    self.new.extension
  end
  
  def initialize
    @binary = "dummy"
    @extension = "dummy"
    @description = "Dummy Description"
  end

  public
    # Returns true iff this engine needs to run (again)
    def do?()
      false
    end

    # Executes this engine
    # Returns an array with three elements
    #  1. true iff there were no fatal errors
    #  2. A list of log messages (cf LogMessage)
    #  3. The raw output of the external program
    def exec()
      return [true, ["No execution code, need to overwrite!"], "No execution code, need to overwrite!"]
    end

    def name
      self.class.name
    end

    def to_s
      @name
    end

    def to_sym
      @binary.to_sym
    end
  
    attr_reader :binary, :extension, :description
    
  protected
    attr_writer :binary, :extension, :description
end
