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

require 'rubygems'

class DependencyManager
  def self.available?(type, name)
    if ( type == :gem )
      begin # TODO move gem checking/loading to a central place?
        gem "#{name}"
        require name
        return true
      rescue Gem::LoadError
        Output.instance.msg("gem #{name} not available")
      end
      return false
    elsif ( type == :binary )
      Output.instance.msg("illegal dependency type")
    else
      Output.instance.msg("illegal dependency type")
    end
  end
end
