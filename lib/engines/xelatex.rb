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

# TODO refactor
Dependency.new('xelatex', :binary, [:engine, 'xelatex'], :essential)

module Chew
  module Engines
    # TODO: document
    class XeLaTeX < Engine

      def initialize
        super
        @binary = 'xelatex'
        @extension = 'pdf'
        @description = 'Uses XeLaTeX to create a PDF'

        @target_file = "#{ParameterManager.instance[:jobname]}.#{extension}"
        @old_hash = hash_result
      end

      def do?
        !File.exist?(@target_file) || hash_result != @old_hash
      end

      def hash_result
        HashManager.hash_file(@target_file, drop_from: /CIDFontType0C|Type1C/)
      end

      def exec
        @old_hash = hash_result

        # Command for the main LaTeX compilation work
        params = ParameterManager.instance
        xelatex = '"xelatex -file-line-error -interaction=nonstopmode #{params[:enginepar]} \"#{params[:jobfile]}\""'

        f = IO.popen(eval(xelatex))
        log = f.readlines.map! { |s| Log.fix(s) }

        parsed_log = TexLogParser.new(log).parse
        { success: File.exist?(@target_file), messages: parsed_log, log: log.join('').strip! }
      end
end
  end
end
