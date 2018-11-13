# Copyright 2010-2018, Raphael Reitzig
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

Dependency.new('biber', :binary, [:extension, 'Biber'], :essential)

module Chew
  module Extensions
# TODO: document
    class Biber
      include Extension

      def initialize
        super
        @name        = 'Biber'
        @description = 'Creates bibliographies (recommended)'
        @sources     = []
      end

      def do?(time)
        return false unless time == 1

        params = ParameterManager.instance

        usesbib   = File.exist?("#{params[:jobname]}.bcf")
        needrerun = false

        if usesbib
          # Collect sources (needed for log parsing)
          @sources = []
          IO.foreach("#{params[:jobname]}.bcf") { |line|
            if /<bcf:datasource[^>]*type="file"[^>]*>(.*?)<\/bcf:datasource>/ =~ line
              @sources.push($~[1])
            end
          }
          @sources.uniq!


          # Aside from the first run (no bbl),
          # there are two things that prompt us to rerun:
          #  * changes to the bcf file (which includes all kinds of things,
          #    including the actual citations)
          #  * changes to the bib sources (which are listed in the bcf file)
          needrerun = !File.exist?("#{params[:jobname]}.bbl") | # Is this the first run?
            HashManager.instance.files_changed?("#{params[:jobname]}.bcf",
                                                *@sources)
          # Note: non-strict OR so that hashes are computed for next run
        end

        usesbib && needrerun
      end

      def exec(time, progress)
        params = ParameterManager.instance

        # Command to process bibtex bibliography if necessary.
        # Uses the following variables:
        # * jobname -- name of the main LaTeX file (without file ending)
        biber = '"biber \"#{params[:jobname]}\""'

        f   = IO.popen(eval(biber))
        log = f.readlines

        # Dig trough output and find errors
        msgs    = []
        errors  = false
        linectr = 1
        log.each { |line|
          loglines = { from: linectr, to: linectr }
          if /^INFO - (.*)$/ =~ line
            msgs.push(TexLogParser::Message.new(message: $~[1], log_lines: loglines, level: :info))
          elsif /^WARN - (.*)$/ =~ line
            msgs.push(TexLogParser::Message.new(message: $~[1], log_lines: loglines, level: :warning))
          elsif /^ERROR - BibTeX subsystem: .*?(#{@sources.map { |s| Regexp.escape(s) }.join('|')}).*?, line (\d+), (.*)$/ =~ line
            srclines = { from: Integer($~[2]), to: Integer($~[2]) }
            msgs.push(TexLogParser::Message.new(message:   $~[3].strip, source_file: $~[1], source_lines: srclines,
                                                log_lines: loglines, level: :error))
            errors = true
          elsif /^ERROR - (.*)$/ =~ line
            msgs.push(TexLogParser::Message.new(message: $~[1], log_lines: loglines, level: error))
            errors = true
          end
          linectr += 1
        }

        { success: !errors, messages: msgs, log: log.join('').strip! }
      end
    end
  end
end
