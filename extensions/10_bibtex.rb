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

class BibTeX < Extension
  def initialize
    super
    
    @name = "bibtex"
    @description = "Creates bibliography"
    
    # For checking whether bibtex has to rerun, we need to keep the 
    # relevant parts of the _.aux file handy.
    @grepfile = "bibtex_aux_grep"
  end

  def do?
    # Collect used bibdata files and style file
    stylefile = []
    bibdata = []
    grepdata = []
    if ( File.exist?("#{$jobname}.aux") )
      File.open("#{$jobname}.aux", "r") { |file|
        while ( line = file.gets )
          if ( /^\\bibdata\{(.+?)\}$/ =~ line )
            bibdata.push "#{$~[1]}.bib"
            grepdata.push line.strip 
          elsif ( /^\\bibstyle\{(.+?)\}$/ =~ line )
            stylefile.push "#{$~[1]}.bst"
            grepdata.push line.strip 
          elsif ( /^\\(bibcite|citation)/ =~ line )
            grepdata.push line.strip 
          end            
        end
      }
    end 
      
    # Write relevant part of the _.aux file into a separate file for hashing
    File.open(@grepfile, "w") { |f|
      f.write grepdata.join("\n")
    }
      
    # Check whether bibtex is necessary at all
    usesbib = bibdata.size > 0
    
    # Check whether a (re)run is needed
    needsrerun = !File.exist?("#{$jobname}.bbl") # Is result still there?
    # Check more closely
    if ( usesbib && !needsrerun )
      fileschanged = false
      
      # Any changes in style or library?
      (stylefile + bibdata).each { |f|
        fileschanged ||= !$hashes.has_key?(f) || filehash(f) != $hashes[f]
      }
      
      # Any relevant changes in the main document?
      documentchanged = !$hashes.has_key?(@grepfile) || filehash(@grepfile) != $hashes[@grepfile]

      needsrerun = fileschanged || documentchanged
    end

    return usesbib && needsrerun
  end

  def exec()
    # Command to process bibtex bibliography if necessary.
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    bibtex = '"bibtex \"#{$jobname}\""'
    progress(3)

    f = IO::popen(eval(bibtex))
    log = f.readlines

    # TODO check for errors/warnings
    return [true,log.join("")]
  end
end
  
$ext = BibTeX.new
