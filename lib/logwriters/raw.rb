# Copyright 2010-2017, Raphael Reitzig
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

module Chew
  module LogWriters
    # TODO: document
    class Raw
      include LogWriter
      class << self
        def name
          'Original Log'
        end

        def description
          'Prints the original log files/outputs into a single file.'
        end

        def to_sym
          :raw
        end

        # Returns the name of the written file, or raises an exception
        # @override
        def write(log, _level = :warning)
          target_file = "#{ParameterManager.instance[:log]}.full"
          File.open(target_file, 'w') { |f| f.write(log.to_s) }
          target_file
        end
      end
    end
  end
end