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

Dependency.new('lualatex', :binary, [:engine, 'lualatex'], :essential) # TODO: refactor

require 'open3'
require 'tex_log_parser'

module Chew
  module Engines
    # TODO: document
    class LuaLaTeX < Engine
      class << self
        def binary
          'lualatex'
        end

        def extension
          'pdf'
        end

        def description
          'Uses LuaLaTeX to create a PDF'
        end
      end

      include Options

      def initialize
        @target_file = "#{ParameterManager.instance[:jobname]}.#{LuaLaTeX.extension}"
        @old_hash = hash_result
      end

      def do?
        !File.exist?(@target_file) || hash_result != @old_hash
      end

      def exec
        @old_hash = hash_result

        raw_log, parsed_log, status = Open3.popen3(
          LuaLaTeX.binary,
          '-file-line-error',
          '-interaction=nonstopmode',
          *params[:enginepar],
          params[:jobfile]
        ) do |_stdin, stdout, stderr, wait_thr|
          pid = wait_thr.pid

          log = stdout.readlines.map! { |s| Log.fix(s) }
          # TODO: incorporate stderr
          parsed_log = TexLogParser.new(log).parse

          exit_status = wait_thr.value # Process::Status object returned.

          [log, parsed_log, exit_status]
        end

        # TODO: incorporate `status`
        # TODO: create class RunResult
        {
          success: File.exist?(@target_file),
          messages: parsed_log,
          log: raw_log.join('').strip!
        }
      end

      private

      def hash_result
        HashManager.hash_file(@target_file,
                              without: /\/CreationDate|\/ModDate|\/ID|\/Type\/XRef\/Index/)
      end
    end
  end
end
