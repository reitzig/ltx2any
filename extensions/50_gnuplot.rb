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
    @dependencies = [["gnuplot", :binary, :essential],
                     ["parallel", :gem, :recommended, "for better performance"]]
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
      }.transpose
    rescue Gem::LoadError
      hint = "Hint: install gem 'parallel' to speed up jobs with many plots."
      log = [[[LogMessage.new(:info, nil, nil, nil, hint)], 
              "#{hint}\n\n"]]
      
      gnuplot_files.each { |f|
        log += compile(gnuplot, f)
        # Output up to ten dots
        # TODO: make nicer output! Eg: [5/10]
        if ( c % [1, (gnuplot_files.size / 10)].max == 0 )
          progress()
        end
        c += 1
      }
      log = log.transpose
    end

    # Log line numbers are wrong since every compile determines log line numbers
    # w.r.t. its own contribution. Later steps will only add the offset of the
    # whole gnuplot block, not those inside.
    offset = 0
    (0..(log[0].size - 1)).each { |i|
      if ( log[0][i].size > 0 )
        internal_offset = 2 # Stuff we print per plot before log excerpt (see :compile)
        log[0][i].map! { |m|
          LogMessage.new(m.type, m.srcfile, m.srcline, 
                         if ( m.logline != nil ) then
                           m.logline.map { |ll| ll + offset + internal_offset} 
                         else
                           nil
                         end,
                         m.msg, if ( m.formatted? ) then :fixed else :none end)
        }
      end
      offset += log[1][i].count(?\n) 
    }

    log[0].flatten!
    errors = log[0].count { |m| m.type == :error }
    return [errors <= 0, log[0], log[1].join]
  end
  
  private 
    def compile(cmd, f)
      log = ""
      msgs = []
      
      io = IO::popen(eval(cmd))
      lines = io.readlines
      output = lines.join("").strip

      log << "# #\n# #{f}\n\n"
      if ( output != "" )
        log << output
        msgs += parse(lines)
      else
        log << "No output from gnuplot, so apparently everything went fine!"
      end
      log << "\n\n"
      
      return [msgs, log]
    end
    
    def parse(strings)
      msgs = []
        
      context = ""
      contextline = 1
      linectr = 1
      strings.each { |line|
        # Messages have the format
        #  * context (at least one line)
        #  * ^ marking the point of issue in its own line
        #  * one line of error statement
        # I have never seen more than one error (seems to abort). 
        # So I'm going to assume that multiple error messages
        # are separated by empty lines.
        if ( /^"(.+?)", line (\d+): (.*)$/ =~ line )
          msgs.push(LogMessage.new(:error, "#{$params["tmpdir"]}/#{$~[1]}", 
                                   [Integer($~[2])], [[contextline, linectr].min, linectr], 
                                   "#{context}#{$~[3].strip}", :fixed))
        elsif ( line.strip == "" )
          context = ""
          contextline = strings.size + 1 # Larger than every line number
        else
          contextline = [contextline, linectr].min
          context += line
        end
        linectr += 1
        # TODO break/strip long lines? Should be able to figure out relevant parts
        #      by position of circumflex
        # TODO drop context here and instead give log line numbers?
      }
        
      return msgs
    end
end

$ext = Gnuplot.new
