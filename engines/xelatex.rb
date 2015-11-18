# Copyright 2010-2015, Raphael Reitzig
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

DependencyManager.add("xelatex", :binary, :recommended)
ParameterManager.instance.addHook(:engine) { |key, val|
  if ( val == :xelatex )
    DependencyManager.make_essential("xelatex", binary)
    DependencyManager.add("cat", :binary, :essential)
    DependencyManager.add("awk", :binary, :essential)
  end
}

class XeLaTeX < Engine

  def initialize
    super
    @heap = []
    @binary = "xelatex"
    @extension = "pdf"
    @description = "Uses xelatex to create a PDF"
  end
  
  def do?
    !@heap[0]
  end

  def exec()
    if ( @heap.size < 2 )
      @heap = [false, ""]
    end

    params = ParameterManager.instance

    # Command for the main LaTeX compilation work.
    # Uses the following variables:
    # * jobfile -- name of the main LaTeX file (with file ending)
    xelatex = '"xelatex -file-line-error -interaction=nonstopmode #{params[:enginepar]} \"#{params[:jobfile]}\""'

    f = IO::popen(eval(xelatex))
    log = f.readlines.map! { |s| Log.fix(s) }

    newHash = -1
    if ( File.exist?("#{params[:jobname]}.#{extension}") )
      newHash = HashManager.hash_file("#{params[:jobname]}.#{extension}",
                                      drop_from: /CIDFontType0C|Type1C/)
    end
    # TODO This is only a hack! What else can be embedded and changing?

    @heap[0] = @heap[1] == newHash
    @heap[1] = newHash

    return [File.exist?("#{params[:jobname]}.#{extension}"), TeXLogParser.parse(log), log.join("").strip!]
  end
end

Engine.add XeLaTeX
