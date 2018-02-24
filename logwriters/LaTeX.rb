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
  def self.name
    'LaTeX'
  end

  def self.description
    'Creates a LaTeX log file; stepping stone to PDF logs.'
  end

  def self.to_sym
    :latex
  end

  # Returns the name of the written file, or raises an exception
  def self.write(log, level = :warning)
    # TODO: compute offsets in a smarter way
    log.to_s if log.rawoffsets == nil # Determines offsets in raw log
    params = ParameterManager.instance

    target_file = "#{params[:log]}.tex"
    File.open(target_file, 'w') { |f|
      # Copy template
      File.open("#{File.dirname(__FILE__)}/logtemplate.tex", 'r') { |template|
        f.write(template.read)
      }
      f.write("\\def\\author{ltx2any}\n\\def\\title{Log for #{params[:user_jobname]}}\n" \
              "\\def\\fulllog{#{File.join(params[:tmpdir], "#{params[:log]}.full")}}\n" \
              "\n\n\\begin{document}")

      f.write("\\section{Log for \\texttt{\\detokenize{#{params[:user_jobname]}}}}\n\n")
      messages = log.only_level(level)

      f.write("\\textbf{Disclaimer:} This is but a digest of the original log file. " \
              "For full detail, check out \\loglink. " \
              'In case we failed to pick up an error or warning, please ' \
              "\\href{https://github.com/akerbos/ltx2any/issues/new}{report it to us}.\n\n")

      f.write("We found \\errlink{\\textbf{#{log.count(:error)}~error#{pls(log.count(:error))}}}, " \
              "\\textsl{#{log.count(:warning)}~warning#{pls(log.count(:warning))}} " \
              "and #{log.count(:info)}~other message#{pls(log.count(:info))} in total.\n\n")

      # Write everything
      messages.each_key { |name|
        # We get one block per tool that ran
        msgs = messages[name][1]

        f.write("\\subsection{\\texttt{#{name}}}\n\n")

        if msgs.empty?
          f.write("Lucky you, \\texttt{#{name}} had nothing to complain about!\n\n")
        else
          f.write("\n\\begin{itemize}\n")

          msgs.each { |m|
            f.write("\n\n\\item\\blockitem\n")

            # Write the error type and source file reference
            if m.type == :error && params[:loglevel] != :error
              f.write("\\linkederror{")
            else
              f.write("\\#{m.type.to_s}{")
            end

            srcline = m.srcline || ['', '']
            srcline.push('') if srcline.length < 2
            f.write("#{makeFileref(m.srcfile, srcline[0], srcline[1])}}\n\n")

            # Write the log message itself
            f.write("\\begin{verbatim}\n")
            if m.formatted?
              f.write(indent(m.msg.strip, 0))
            else
              f.write(break_at_spaces(m.msg.strip, 68, 1))
            end
            f.write("\n\\end{verbatim}")

            # Write the raw log reference
            unless m.logline.nil?
              # We have line offsets in the raw log!
              logline = m.logline.map { |i| i + log.rawoffsets[name] }
              logline.push('') if logline.length < 2
              f.write("\n\n\\logref{#{logline[0]}}{#{logline[1]}}")
            end

            f.write("\n\\endblockitem\n\n")
          }

          f.write("\n\\end{itemize}")
        end
      }

      f.write("\n\n\\end{document}")
    }

    target_file
  end

  private

  def self.makeFileref(file, linefrom, lineto)
    fileref = ''
    unless file.nil?
      # file = file.gsub(/_/, '\_')
      fileref = "\\fileref{#{file}}{#{linefrom}}{#{lineto}}"
    end
    fileref
  end
end

LogWriter.add LaTeX
