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

class Gnuplot < Extension
  def initialize
    super
    
    @name = "gnuplot"
    @description = "Executes generated gnuplot files"
  end

  def do?
    # Check whether there are any _.gnuplot files that have changed
    !Dir.entries(".").delete_if { |f|
      (/\.gnuplot$/ !~ f) || ($hashes.has_key?(f) && filehash(f) == $hashes[f])
    }.empty?
  end

  def exec()
    # Command to process bibtex bibliography if necessary.
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    gnuplot = '"gnuplot \"#{f}\" 2>&1"'

    # Filter out non-gnuplot files and such that did not change since last run
    gnuplot_files = Dir.entries(".").delete_if { |f|
      (/\.gnuplot$/ !~ f) || ($hashes.has_key?(f) && filehash(f) == $hashes[f])
    }

    # Run gnuplot for each remaining file
    log = ""
    c = 1
    begin # TODO move gem checking/loading to a central place?
      gem "parallel"
      require 'parallel'
      
      log = Parallel.map(gnuplot_files) { |f|
        ilog = compile(gnuplot, f)
        # Output up to ten dots
        # TODO: make nicer output! Eg: [5/10]
        if ( c % [1, (gnuplot_files.size / 10)].max == 0 )
          progress()
        end
        c += 1
        ilog
      }.join
    rescue Gem::LoadError
      log << "Hint: install gem 'parallel' to speed up jobs with many plots.\n\n"
      
      gnuplot_files.each { |f|
        log << compile(gnuplot, f)
        # Output up to ten dots
        # TODO: make nicer output! Eg: [5/10]
        if ( c % [1, (gnuplot_files.size / 10)].max == 0 )
          progress()
        end
        c += 1
      }
    end

    # TODO check for errors/warnings
    return [true, log]
  end
  
  def compile(cmd, f)
    log = ""
    
    io = IO::popen(eval(cmd))
    output = io.readlines.join("").strip

    log << "# #\n# #{f}\n\n"
    if ( output != "" )
      log << output
    else
      log << "No output from gnuplot, so apparently everything went fine!"
    end
    log << "\n\n"
    
    return log
  end
end

$ext = Gnuplot.new
