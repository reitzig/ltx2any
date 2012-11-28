# Copyright 2010-2012, Raphael Reitzig
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

$tgt = Target.new(
  "pdflatex",

  "pdf",

  "Uses pdflatex to create a PDF",

  {},

  {},

  lambda { |parent|
    !parent.heap[0]
  },

  lambda { |parent|
    if ( parent.heap.size < 2 )
      parent.heap = [false, ""]
    end

    # Command for the main LaTeX compilation work.
    # Uses the following variables:
    # * jobfile -- name of the main LaTeX file (with file ending)
    # * tmpdir  -- the output directory
    pdflatex = '"pdflatex -file-line-error -interaction=nonstopmode #{$jobfile}"'

    f = IO::popen(eval(pdflatex))
    log = f.readlines
    # TODO fix equality check!

    newHash = -1
    if ( File.exist?("#{$jobname}.#{parent.extension}") )
      newHash = `cat #{$jobname}.#{parent.extension} | grep -a -v "/CreationDate\\|/ModDate\\|/ID" | md5sum`.strip
    end

    parent.heap[0] = parent.heap[1] == newHash
    parent.heap[1] = newHash

    # Implement error/warning detection: 
    # Errors: * `^file:line: msg$`
    #         * ``
    # Warnings: * `^(Under|Over)full ... at lines <line>$
    #           * `Warning` --> line? paragraph?
    #
    # Beachte: ^(\) )?(<file> ... ) bei eingebundenen Dateien
    return [true, log.join("")]
  }
)
