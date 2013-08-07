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

class MakeIndex < Extension
  def initialize
    super
    
    @name = "makeindex"
    @description = "Creates an index"
    @dependencies = [["makeindex", :binary, :essential]]
  end

  def do?
    File.exist?("#{$jobname}.idx")
  end

  def exec()
    # Command to create the index if necessary. Provide two versions,
    # one without and one with stylefile
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    # * mistyle -- name of the makeindex style file (with file ending)
    makeindex = { "default" => '"makeindex -q \"#{$jobname}\""',
                  "styled"  => '"makeindex -q -s \"#{mistyle}\" \"#{$jobname}\""'}
    progress(3)
  
    version = "default"
    mistyle = nil
    Dir["*.ist"].each { |f|
      version = "styled"
      mistyle = f
    }

    f = IO::popen(eval(makeindex[version]))
    log = f.readlines

    File.open("#{$jobname}.ilg", "r") { |file|
      while ( line = file.gets )
        log << line
      end
    }

    # TODO implement error/warning recognition
    return [true, [], log.join("")]
  end
end

$ext = MakeIndex.new
