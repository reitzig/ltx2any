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

class Extension
  attr_accessor :name, :description, :codes, :params
  
  def initialize(name, description, codes, params, do_lambda, exec_lambda)
    @name = name
    @description = description
    @codes = codes
    @params = params
    @do_lambda = do_lambda
    @exec_lambda = exec_lambda 
  end
  
  def do?()
    @do_lambda.call
  end

  def exec()
    @exec_lambda.call
  end

  def to_s
    @name
  end
end
