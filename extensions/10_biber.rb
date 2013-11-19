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

class Biber < Extension
  def initialize(params)
    super(params)
    
    @name = "biber"
    @description = "Creates bibliography"
    @dependencies = [["biber", :binary, :essential]]
    
    @sources = []
  end

  def do?
    usesbib = File.exist?("#{@params[:jobname]}.bcf")
    
    if ( usesbib )
      # Collect sources (needed for log parsing)
      @sources = []
      IO.foreach("#{@params[:jobname]}.bcf") { |line|
        if ( /<bcf:datasource[^>]*type="file"[^>]*>(.*?)<\/bcf:datasource>/ =~ line )
          @sources.push($~[1])
        end
      }
      @sources.uniq!
    end    
      
    needrerun = !File.exist?("#{@params[:jobname]}.bbl") # Is this the first run?
    if ( usesbib && !needrerun )
      # There are two things that prompt us to rerun:
      #  * changes to the bcf file (which includes all kinds of things,
      #    including the actual citations)
      #  * changes to the bib sources (which are listed in the bcf file)
      
      # Has the bcf file changed?
      needrerun ||= !$hashes.has_key?("#{@params[:jobname]}.bcf") || filehash("#{@params[:jobname]}.bcf") != $hashes["#{@params[:jobname]}.bcf"]
      
      if ( !needrerun )
        # Have bibliography files changes?
        @sources.each { |f|
          needrerun ||= !$hashes.has_key?(f) || filehash(f) != $hashes[f]
          
          # Don't do more than necessary!
          if ( needrerun )
            break
          end
        }
      end
    end
    
    return usesbib && needrerun
  end

  def exec()
    # Command to process bibtex bibliography if necessary.
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    biber = '"biber \"#{@params[:jobname]}\""'
    progress(3)

    f = IO::popen(eval(biber))
    log = f.readlines

    # Dig trough output and find errors
    msgs = []
    errors = false
    linectr = 1
    log.each { |line|
      if ( /^INFO - (.*)$/ =~ line )
        msgs.push(LogMessage.new(:info, nil, nil, [linectr], $~[1]))
      elsif ( /^WARN - (.*)$/ =~ line )
        msgs.push(LogMessage.new(:warning, nil, nil, [linectr], $~[1]))
      elsif ( /^ERROR - BibTeX subsystem: .*?(#{@sources.map { |s| Regexp.escape(s) }.join("|")}).*?, line (\d+), (.*)$/ =~ line )
        msgs.push(LogMessage.new(:error, $~[1], [Integer($~[2])], [linectr], $~[3].strip))
        errors = true
      elsif ( /^ERROR - (.*)$/ =~ line )
        msgs.push(LogMessage.new(:error, nil, nil, [linectr], $~[1]))
        errors = true
      end
      linectr += 1
    }

    return [!errors, msgs, log.join("").strip!]
  end
end
  
$extension = Biber
