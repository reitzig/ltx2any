# Copyright 2010-2018, Raphael Reitzig
#
# This file is part of chew.
#
# chew is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# chew is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with chew. If not, see <http://www.gnu.org/licenses/>.

module Chew
  module Engines
    class Engine
      class << self
        def to_sym
          to_s.downcase.to_sym
        end

        def to_s
          name.split('::').last
        end

        # @return [String]
        def description
          raise 'Need to override `description`'
        end

        # @return [String]
        def binary
          raise 'Need to override `binary`'
        end

        # @return [String]
        def extension
          raise 'Need to override `extension`'
        end
      end

      # Returns true iff this engine needs to run (again)
      #
      # @return [true,false]
      def do?
        raise 'Need to override `do?`'
      end

      # Executes this engine
      # Returns a dictionary with three entries:
      #  - sucess: true iff there were no fatal errors
      #  - messages: A list of log messages (cf LogMessage)
      #  - log: The raw output of the external program
      #
      # @return [Hash]
      def exec
        raise 'Need to override `exec?`'
      end
    end
  end
end

