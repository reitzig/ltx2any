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

class TikZExt < Extension
  def initialize
    super
    
    @name = "tikzext"
    @description = "Compiles externalized TikZ images"
    @codes = { "ir" => [nil, "imagerebuild", "If set, externalised TikZ images are rebuilt."]}
    @params = { "imagerebuild" => false }
    @dependencies = [["pdflatex", :binary, :essential],
                     ["parallel", :gem, :recommended, "for better performance"]]
  end

  def do?
    File.exist?("#{$jobname}.figlist")
  end

  def exec()
    # Command to process bibtex bibliography if necessary.
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    pdflatex = '"pdflatex -shell-escape -file-line-error -interaction=batchmode -jobname \"#{fig}\" \"\\\def\\\tikzexternalrealjob{#{$jobname}}\\\input{#{$jobname}}\" 2>&1"'

    figures = []
    IO.foreach("#{$jobname}.figlist") { |fig|
      if ( fig.strip != "" )
       figures.push(fig.strip)
      end
    }
     
    # Run pdflatex for each figure
    log = ""
    c = 1
    begin # TODO move gem checking/loading to a central place?
      gem "parallel"
      require 'parallel'
      
      log = Parallel.map(figures) { |fig|
        ilog = compile(pdflatex, fig)
        # Output up to ten dots
        # TODO: make nicer output! Eg: [5/10]
        if ( c % [1, (figures.size / 10)].max == 0 )
          progress()
        end
        c += 1
        ilog
      }.join
    rescue Gem::LoadError
      log << "Hint: install gem 'parallel' to speed up jobs with many externalized figures.\n\n"
      
      figures.each { |fig|
        log << compile(pdflatex, fig)
        # Output up to ten dots
        # TODO: make nicer output! Eg: [5/10]
        if ( c % [1, (figures.size / 10)].max == 0 )
          progress()
        end
        c += 1
      }
    end
  
    # TODO check for errors/warnings
    return [true, [], log]
  end
  
  def compile(cmd, fig)
    log = ""
    
    if ( $params["imagerebuild"] || !File.exist?("#{fig}.pdf") )
      io = IO::popen(eval(cmd))
      output = io.readlines.join("").strip

      if ( !File.exist?("#{fig}.pdf") ) 
        log << "Fatal error on #{fig}. See #{$params["tmpdir"]}/#{fig}.log for details.\n"
      end
    end
    
    return log
  end
end

$ext = TikZExt.new
