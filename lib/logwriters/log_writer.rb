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
  module LogWriters
    # TODO: document
    module LogWriter
      @@list         = {}
      @@dependencies = DependencyManager.list(source: [:core, 'LogWriter'])

      # @param [LogWriter] lw
      def self.add(lw)
        @@list[lw.to_sym] = lw
      end

      # @return [Array<LogWriter>]
      def self.list
        @@list.values
      end

      # @return [LogWriter]
      def self.[](key)
        @@list[key]
      end

      # @return [String]
      def self.name
        raise NotImplementedError
      end

      # @return [String]
      def self.description
        raise NotImplementedError
      end

      # @return [Symbol]
      def self.to_sym
        raise NotImplementedError
      end

      def self.to_s
        name
      end

      # Returns the name of the written file, or raises an exception
      # @param [Log] log
      # @param [:error,:warning,:info]
      # @return [String]
      def self.write(log, level = :warning)
        raise NotImplementedError
      end

      protected

      def self.pls(count)
        if count == 1
          ''
        else
          's'
        end
      end

      def self.indent(s, indent)
        s.split(/\n+/).map { |line| (' ' * indent) + line }.join("\n")
      end

      def self.break_at_spaces(s, length, indent)
        words = s.split(/\s+/)

        res  = ''
        line = ' ' * [0, indent - 1].max
        words.each do |w|
          newline = line + ' ' + w
          if newline.length > length
            res  += line + "\n"
            line = (' ' * indent) + w
          else
            line = newline
          end
        end

        res + line
      end
    end
  end
end
