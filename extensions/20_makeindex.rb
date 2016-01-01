# Copyright 2010-2016, Raphael Reitzig
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

DependencyManager.add("makeindex", :binary, :essential)

class MakeIndex < Extension
  def initialize
    super
    
    @name = "makeindex"
    @description = "Creates an index"
  end

  def do?(time)
    return false unless time == 1
    
    params = ParameterManager.instance
    
       File.exist?("#{params[:jobname]}.idx") \
    && (   !File.exist?("#{params[:jobname]}.ind") \
         | HashManager.instance.files_changed?("#{params[:jobname]}.idx") 
         # Note: non-strict OR so that hashes are computed for next run
       )
  end

  def exec(time, progress)
    params = ParameterManager.instance
    
    # Command to create the index if necessary. Provide two versions,
    # one without and one with stylefile
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    # * mistyle -- name of the makeindex style file (with file ending)
    makeindex = { "default" => '"makeindex -q \"#{params[:jobname]}\" 2>&1"',
                  "styled"  => '"makeindex -q -s \"#{mistyle}\" \"#{params[:jobname]}\" 2>&1"'}
  
    version = "default"
    mistyle = nil
    Dir["*.ist"].each { |f|
      version = "styled"
      mistyle = f
    }

    # Even in quiet mode, some critical errors (e.g. regarding -g) 
    # only end up in the error stream, but not in the file. Doh.
    log1 = []
    IO::popen(eval(makeindex[version])) { |f|
     log1 = f.readlines
    }

    log2 = []
    File.open("#{params[:jobname]}.ilg", "r") { |f|
      log2 = f.readlines
    }

    log = [log2[0]] + log1 + log2[1,log2.length]

    msgs = []
    current = []
    linectr = 1
    errors = false
    log.each { |line|
      if ( /^!! (.*?) \(file = (.+?), line = (\d+)\):$/ =~ line )
        current = [:error, $~[2], [Integer($~[3])], [linectr], "#{$~[1]}: "]
        errors = true
      elsif ( /^\#\# (.*?) \(input = (.+?), line = (\d+); output = .+?, line = \d+\):$/ =~ line )
        current = [:warning, $~[2], [Integer($~[3])], [linectr], "#{$~[1]}: "]
      elsif ( current != [] && /^\s+-- (.*)$/ =~ line )
        current[3][1] = linectr
        msgs.push(LogMessage.new(current[0], current[1], current[2], 
                                 current[3], current[4] + $~[1].strip))
        current = []
      elsif ( /Option -g invalid/ =~ line )
        msgs.push(LogMessage.new(:error, nil, nil, [linectr], line.strip))
        errors = true
      elsif ( /Can't create output index file/ =~ line )
        msgs.push(LogMessage.new(:error, nil, nil, [linectr], line.strip))
        errors = true
      end
      linectr += 1
    }

    return [!errors, msgs, log.join("").strip!]
  end
end

Extension.add MakeIndex
