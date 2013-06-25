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

$ext = Extension.new(
  "bibtex",

  "Creates bibliography",

  {},

  {},

  lambda {
    found = false
    
    if ( File.exist?("#{$jobname}.aux") )
      File.open("#{$jobname}.aux", "r") { |file|
        while ( line = file.gets )
          if ( !(/^\\bibdata\{.+?\}$/ !~ line) )
            found = true
          end
        end
      }
    end

    if ( found )
      # check wether !File.exist?("#{$jobname}.bbl")
      # check wether `cat mathesis.aux | grep -e '^\\\\bib'` has changed
      # check wether ?.bib has changed
    end

    return found
  },

  lambda {
    # Command to process bibtex bibliography if necessary.
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    bibtex = '"bibtex #{$jobname}"'
    progress(3)

    f = IO::popen(eval(bibtex))
    log = f.readlines

    # TODO check for errors/warnings
    return [true,log.join("")]
  })
