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

class Engine
  def initialize
    @name = "Dummy Name"
    @extension = "dummy"
    @description = "Dummy Description"
    @codes = {}
    @params = {}
    @heap = []
  end

  public
    def do?()
      false
    end

    def exec()
      return [true, "No execution code, need to overwrite!"]
    end

    def to_s
      @name
    end
  
  
    attr_reader :name, :extension, :description, :codes, :params, :heap
    attr_writer :heap
    
  protected
    attr_writer :name, :extension, :description, :codes, :params
end
