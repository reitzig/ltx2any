# frozen_string_literal: true

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

class LaTeX < LogWriter
  class << self
    def name
      'LaTeX'
    end

    def description
      'Creates a LaTeX log file; stepping stone to PDF logs.'
    end

    def to_sym
      :latex
    end

    # Returns the name of the written file, or raises an exception
    def write(log, level = :warning)
      params = ParameterManager.instance

      target_file = "#{params[:log]}.tex"
      File.open(target_file, 'w') do |f|
        # Copy template
        File.open("#{File.dirname(__FILE__)}/logtemplate.tex", 'r') do |template|
          f.write(template.read)
        end
        f.write("\\def\\author{ltx2any}\n\\def\\title{Log for #{params[:user_jobname]}}\n" \
                "\\def\\fulllog{#{File.join(params[:tmpdir], "#{params[:log]}.full")}}\n" \
                "\n\n\\begin{document}")

        f.write("\\section{Log for \\texttt{\\detokenize{#{params[:user_jobname]}}}}\n\n")
        messages = log.only_level(level)

        f.write('\\textbf{Disclaimer:} This is but a digest of the original log file. ' \
                'For full detail, check out \\loglink. ' \
                'In case we failed to pick up an error or warning, please ' \
                "\\href{https://github.com/akerbos/ltx2any/issues/new}{report it to us}.\n\n")

        f.write("We found \\errlink{\\textbf{#{log.count(:error)}~error#{pls(log.count(:error))}}}, " \
                "\\textsl{#{log.count(:warning)}~warning#{pls(log.count(:warning))}} " \
                "and #{log.count(:info)}~other message#{pls(log.count(:info))} in total.\n\n")

        # Write everything
        messages.each_key do |name|
          # We get one block per tool that ran
          msgs = messages[name][1]

          f.write("\\subsection{\\texttt{#{name}}}\n\n")

          if msgs.empty?
            f.write("Lucky you, \\texttt{#{name}} had nothing to complain about!\n\n")
          else
            f.write("\n\\begin{itemize}\n")

            msgs.each do |m|
              f.write("\n\n\\item\\blockitem\n")

              # Write the error type and source file reference
              if m.level == :error && params[:loglevel] != :error
                f.write('\\linkederror{')
              else
                f.write("\\#{m.level}{")
              end

              to_line = m.source_lines[:from] == m.source_lines[:to] ? '' : m.source_lines[:to]
              f.write("#{makeFileref(m.source_file, m.source_lines[:from], to_line)}}\n\n")

              # Write the log message itself
              f.write("\\begin{verbatim}\n")
              if m.preformatted
                f.write(indent(m.message.strip, 0))
              else
                f.write(break_at_spaces(m.message.strip, 68, 1))
              end
              f.write("\n\\end{verbatim}")

              # Write the raw log reference
              unless m.log_lines.nil?
                # We have line offsets in the raw log!
                to_line = m.log_lines[:from] == m.log_lines[:to] ? '' : m.log_lines[:to]
                f.write("\n\n\\logref{#{m.log_lines[:from]}}{#{to_line}}")
              end

              f.write("\n\\endblockitem\n\n")
            end

            f.write("\n\\end{itemize}")
          end
        end

        f.write("\n\n\\end{document}")
      end

      target_file
    end

    private

    def makeFileref(file, linefrom, lineto)
      fileref = ''
      unless file.nil?
        # file = file.gsub(/_/, '\_')
        fileref = "\\fileref{#{file}}{#{linefrom}}{#{lineto}}"
      end
      fileref
    end
  end
end

LogWriter.add LaTeX
