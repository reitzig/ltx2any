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

DependencyManager.add("bibtex", :binary, :essential)

class BibTeX < Extension
  def initialize
    super    
    @name = "BibTeX"
    @description = "Creates bibliography (old)"
    
    # For checking whether bibtex has to rerun, we need to keep the 
    # relevant parts of the _.aux file handy.
    # TODO use internal store?
    @grepfile = "bibtex_aux_grep"
  end

  def do?
    params = ParameterManager.instance
    
    # Collect used bibdata files and style file
    stylefile = []
    bibdata = []
    grepdata = []
    if ( File.exist?("#{params[:jobname]}.aux") )
      File.open("#{params[:jobname]}.aux", "r") { |file|
        while ( line = file.gets )
          if ( /^\\bibdata\{(.+?)\}$/ =~ line )
            # If commas occur, add both a split version (multiple files)
            # and the hole string (filename with comma), to be safe.
            bibdata += $~[1].split(",").map { |s| "#{s}.bib" } + [$~[1]]
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
    needsrerun = !File.exist?("#{params[:jobname]}.bbl") # Is result still there?
    # Check more closely
    if ( usesbib && !needsrerun )
      fileschanged = false
      
      # Any changes in style or library?
      (stylefile + bibdata).each { |f|
        fileschanged ||= File.exist?(f) && (!$hashes.has_key?(f) || filehash(f) != $hashes[f])
      }
      
      # Any relevant changes in the main document?
      documentchanged = !$hashes.has_key?(@grepfile) || filehash(@grepfile) != $hashes[@grepfile]

      needsrerun = fileschanged || documentchanged
    end

    return usesbib && needsrerun
  end

  def exec(progress)
    params = ParameterManager.instance
    
    # Command to process bibtex bibliography if necessary.
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    bibtex = '"bibtex \"#{params[:jobname]}\""'

    f = IO::popen(eval(bibtex))
    log = f.readlines

    # Dig trough output and find errors
    msgs = []
    errors = false
    linectr = 1
    lastline = ""
    log.each { |line|
      if ( /^Warning--(.*)$/ =~ line )
        msgs.push(LogMessage.new(:warning, nil, nil, [linectr], $~[1]))
      elsif ( /^(.*?)---line (\d+) of file (.*)$/ =~ line )
        msg = $~[1].strip
        logline = [linectr]
        if ( msg == "" )
          # Sometimes the message can be on the last line
          msg = lastline
          logline = [linectr - 1, linectr]
        end
          
        msgs.push(LogMessage.new(:error, $~[3], [Integer($~[2])], logline, msg))
        errors = true
      end
      linectr += 1
      lastline = line
    }

    return [!errors, msgs, log.join("").strip!]
  end
end
  
Extension.add BibTeX
