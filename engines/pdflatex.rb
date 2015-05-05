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

DependencyManager.add("pdflatex", :binary, :recommended)
ParameterManager.instance.addHook(:engine) { |key, val|
  if ( val == :pdflatex )
    DependencyManager.make_essential("pdflatex", binary)
    DependencyManager.add("cat", :binary, :essential)
    DependencyManager.add("grep", :binary, :essential)
  end
}

class PdfLaTeX < Engine
  
  def initialize
    super
    @heap = []
    @binary = "pdflatex"
    @extension = "pdf"
    @description = "Uses pdflatex to create a PDF"
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
    pdflatex = '"pdflatex -file-line-error -interaction=nonstopmode \"#{params[:jobfile]}\""'

    f = IO::popen(eval(pdflatex))
    log = f.readlines.map! { |s| Log.fix(s) }

    newHash = -1
    if ( File.exist?("#{params[:jobname]}.#{extension}") )
      newHash = Digest::MD5.hexdigest(`cat "#{params[:jobname]}.#{extension}" | grep -a -v "/CreationDate\\|/ModDate\\|/ID"`.strip)
      # TODO remove binary dependencies
    end

    @heap[0] = @heap[1] == newHash
    @heap[1] = newHash

    return [File.exist?("#{params[:jobname]}.#{extension}"), TeXLogParser.parse(log), log.join("").strip!]
  end
end

Engine.add PdfLaTeX
