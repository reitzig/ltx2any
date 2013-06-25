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
  "gnuplot",

  "Renders generated gnuplot files",

  {},

  {},

  lambda {
    !Dir.entries(".").delete_if { |f|
      (/\.gnuplot$/ !~ f) || ($hashes.has_key?(f) && filehash(f) == $hashes[f])
    }.empty?
  },

  lambda {
    # Command to process bibtex bibliography if necessary.
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    gnuplot = '"gnuplot #{f} 2>&1"'

    # Filter out non-gnuplot files and such that did not change since last run
    gnuplot_files = Dir.entries(".").delete_if { |f|
      (/\.gnuplot$/ !~ f) || ($hashes.has_key?(f) && filehash(f) == $hashes[f])
    }

    # Run gnuplot
    # TODO parallelise
    log = ""
    c = 1
    gnuplot_files.each { |f|
      io = IO::popen(eval(gnuplot))
      output = io.readlines.join("").strip

      if ( output != "" )
        log << "# #\n# #{f}\n\n"
        log << output + "\n\n"
      end

      # Output up to ten dots
      if ( c % [1, (gnuplot_files.size / 10)].max == 0 )
        progress()
      end
      c += 1
    }

    # TODO check for errors/warnings
    return [true,log]
  })
