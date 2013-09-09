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
    File.exist?("#{$jobname}.figlist") && ($params["imagerebuild"] || 
      IO.readlines("#{$jobname}.figlist").select { |fig|
        !File.exist?("#{fig.strip}.pdf")
      }.size > 0 )
  end

  def exec()
    # Command to process externalised TikZ images if necessary.
    # Uses the following variables:
    # * $params["engine"] -- Engine used by the main job.
    # * $jobname -- name of the main LaTeX file (without file ending)
    pdflatex = '"#{$params["engine"]} -shell-escape -file-line-error -interaction=batchmode -jobname \"#{fig}\" \"\\\def\\\tikzexternalrealjob{#{$jobname}}\\\input{#{$jobname}}\" 2>&1"'

    figures = IO.readlines("#{$jobname}.figlist").map { |fig|
      if ( fig.strip != "" )
        fig.strip
      else
        nil
      end
    }.compact.select { |fig|
      $params["imagerebuild"] || !File.exist?("#{fig}.pdf")
    }
    
    # Run (latex) engine for each figure
    log = [[], ""]
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
      }.transpose
    rescue Gem::LoadError
      hint = "Hint: install gem 'parallel' to speed up jobs with many externalized figures."
      log = [[[LogMessage.new(:info, nil, nil, nil, hint)], 
              "#{hint}\n\n"]]
      
      figures.each { |fig|
        log += compile(pdflatex, fig)
        # Output up to ten dots
        # TODO: make nicer output! Eg: [5/10]
        if ( c % [1, (figures.size / 10)].max == 0 )
          progress()
        end
        c += 1
      }
      log = log.transpose
    end
  
    # Log line numbers are wrong since every compile determines log line numbers
    # w.r.t. its own contribution. Later steps will only add the offset of the
    # whole tikzext block, not those inside.
    offset = 0
    (0..(log[0].size - 1)).each { |i|
      if ( log[0][i].size > 0 )
        internal_offset = 5 # Stuff we print per figure before log excerpt (see :compile)
        log[0][i].map! { |m|
          LogMessage.new(m.type, m.srcfile, m.srcline, 
                         if ( m.logline != nil ) then
                           m.logline.map { |ll| ll + offset + internal_offset - 1} # -1 because we drop first line!
                         else
                           nil
                         end,
                         m.msg, if ( m.formatted? ) then :fixed else :none end)
        }
        
        log[0][i] = [LogMessage.new(:info, nil, nil, nil, 
                                    "The following messages refer to figure\n  #{figures[i]}.\n" + 
                                    "See\n  #{$params["tmpdir"]}/#{figures[i]}.log\nfor the full log.", :fixed)
                    ] + log[0][i]
      else
        log[0][i] += [LogMessage.new(:info, nil, nil, nil, 
                                     "No messages for figure\n  #{figures[i]}.\nfound. " + 
                                     "See\n  #{$params["tmpdir"]}/#{figures[i]}.log\nfor the full log.", :fixed)
                     ]
      end
      offset += log[1][i].count(?\n) 
    }
    
    log[0].flatten!
    errors = log[0].count { |m| m.type == :error }
    return [errors <= 0, log[0], log[1].join]
  end
  
  private
    def compile(cmd, fig)
      msgs = []
      log = "# #\n# Figure: #{fig}\n#   See #{$params["tmpdir"]}/#{fig}.log for full log.\n\n"
             
      # Run twice to clean up log?
      # IO::popen(eval(cmd)).readlines
      io = IO::popen(eval(cmd)).readlines
      # Shell output does not contain error messages -> read log
      output = File.open("#{fig}.log", "r") { |f|
        f.readlines.map { |s| Log.fix(s) }
      }
      
      # These seems to describe reliable boundaries of that part in the log
      # which deals with the processed TikZ figure.
      startregexp = /^\\openout5 = `#{fig}\.dpth'\.\s*$/
      endregexp = /^\[\d+\s*$/
      
      # Cut out relevant part for raw log (heuristic)
      string = output.drop_while { |line|
        startregexp !~ line
      }.take_while { |line|
        endregexp !~ line
      }.drop(1).join("").strip

      if ( string != "" )
        log << "<snip>\n\n#{string}\n\n<snip>"
      else
        log << "No errors detected."
      end
      
      # Parse whole log for messages (needed for filenames) but restrict
      # to messages from interesting part
      msgs = TeXLogParser.parse(output, startregexp, endregexp)

      # Still necessary? Should get *some* error from the recursive call.
      # if ( !File.exist?("#{fig}.pdf") ) 
      #   log << "Fatal error on #{fig}. See #{$params["tmpdir"]}/#{fig}.log for details.\n"
      # end
      log << "\n\n"
      
      return [msgs, log]
    end
end

$ext = TikZExt.new
