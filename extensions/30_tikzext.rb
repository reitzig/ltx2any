# Copyright 2010-2013, Raphael Reitzig
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

$ext = Extension.new(
  "tikzext",

  "Compiles externalized TikZ images",

  { "ir" => [nil, "imagerebuild", "If set, externalised TikZ images are rebuilt."]},

  { "imagerebuild" => false },

  lambda { File.exist?("#{$jobname}.figlist") },

  lambda {
    # Command to process bibtex bibliography if necessary.
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    pdflatex = '"pdflatex -shell-escape -file-line-error -interaction=batchmode -jobname \"#{fig}\" \"\\\def\\\tikzexternalrealjob{#{$jobname}}\\\input{#{$jobname}}\" 2>&1"'

    # TODO detect changes in **/*.tikz --> delete according PDF (?)

    log = ""
    number = Integer(`wc -l #{} #{$jobname}.figlist`.split(" ")[0].strip)
    c = 1

    # Run pdflatex for each figure
    # TODO parallelise
    IO.foreach("#{$jobname}.figlist") { |fig|
      fig = fig.strip

      if ( $params["imagerebuild"] || !File.exist?("#{fig}.pdf") )
        io = IO::popen(eval(pdflatex))
        output = io.readlines.join("").strip

        if ( !File.exist?("#{fig}.pdf") )
          log << "Error on #{fig}. See #{fig}.log \n"
        end
      end

      # Output up to ten dots
      if ( c % [1, (number / 10)].max == 0 )
        progress()
      end
      c += 1
    }

    # TODO check for errors/warnings
    return [true,log]
  })



