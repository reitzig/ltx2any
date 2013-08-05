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

class LuaLaTeX < Engine

  def initialize
    super
    
    @name = "lualatex"
    @extension = "pdf"
    @description = "Uses lualatex to create a PDF"
  end
  
  def do?
    !@heap[0]
  end

  def exec()
    if ( @heap.size < 2 )
      @heap = [false, ""]
    end

    # Command for the main LaTeX compilation work.
    # Uses the following variables:
    # * jobfile -- name of the main LaTeX file (with file ending)
    lualatex = '"lualatex -file-line-error -interaction=nonstopmode #{$jobfile}"'

    f = IO::popen(eval(lualatex))
    log = f.readlines

    newHash = -1
    if ( File.exist?("#{$jobname}.#{extension}") )
      newHash = `cat #{$jobname}.#{extension} | grep -a -v "/CreationDate|/ModDate|/ID|/Type/XRef/Index" | md5sum`.strip
    end

    @heap[0] = @heap[1] == newHash
    @heap[1] = newHash

    # Implement error/warning detection: 
    # Errors: * `^file:line: msg$`
    #         * ``
    # Warnings: * `^(Under|Over)full ... at lines <line>$
    #           * `Warning` --> line? paragraph?
    #
    # Beachte: ^(\) )?(<file> ... ) bei eingebundenen Dateien
    return [true, log.join("")]
  end
end

$tgt = LuaLaTeX.new
