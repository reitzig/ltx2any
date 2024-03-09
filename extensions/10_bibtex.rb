# Copyright 2010-2018, Raphael Reitzig
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

Dependency.new('bibtex', :binary, [:extension, 'BibTeX'], :essential)

# TODO: document
class BibTeX < Extension
  def initialize
    super
    @name = 'BibTeX'
    @description = 'Creates bibliographies (old)'

    # For checking whether bibtex has to rerun, we need to keep the
    # relevant parts of the _.aux file handy.
    # TODO use internal store?
    @grepfile = 'bibtex_aux_grep'
  end

  def do?(time)
    return false unless time == 1

    params = ParameterManager.instance

    # Collect used bibdata files and style file
    stylefile = []
    bibdata = []
    grepdata = []
    if File.exist?("#{params[:jobname]}.aux")
      File.open("#{params[:jobname]}.aux", 'r') do |file|
        while (line = file.gets)
          if /^\\bibdata{(.+?)}$/ =~ line
            # If commas occur, add both a split version (multiple files)
            # and the hole string (filename with comma), to be safe.
            bibdata += $~[1].split(',').map { |s| "#{s}.bib" } + [$~[1]]
            grepdata.push line.strip
          elsif /^\\bibstyle{(.+?)}$/ =~ line
            stylefile.push "#{$~[1]}.bst"
            grepdata.push line.strip
          elsif /^\\(bibcite|citation)/ =~ line
            grepdata.push line.strip
          end
        end
      end
    end

    # Check whether bibtex is necessary at all
    usesbib = !bibdata.empty?

    # Write relevant part of the _.aux file into a separate file for hashing
    File.write(@grepfile, grepdata.join("\n")) if usesbib

    # Check whether a (re)run is needed
    needsrerun = !File.exist?("#{params[:jobname]}.bbl") | # Is result still there?
                 HashManager.instance.files_changed?(*stylefile, *bibdata, @grepfile)
    # NOTE: non-strict OR so that hashes get computed and stored
    #       for next run!

    usesbib && needsrerun
  end

  def exec(_time, _progress)
    params = ParameterManager.instance

    # Command to process bibtex bibliography if necessary.
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    bibtex = '"bibtex \"#{params[:jobname]}\""'

    f = IO.popen(eval(bibtex))
    log = f.readlines

    # Dig trough output and find errors
    msgs = []
    errors = false
    linectr = 1
    lastline = ''
    log.each do |line|
      if /^Warning--(.*)$/ =~ line
        msgs.push(TexLogParser::Message.new(message: $~[1],
                                            log_lines: { from: linectr, to: linectr },
                                            level: :warning))
      elsif /^(.*?)---line (\d+) of file (.*)$/ =~ line
        msg = $~[1].strip
        loglines = { from: linectr, to: linectr }
        if msg == ''
          # Sometimes the message can be on the last line
          msg = lastline
          loglines = { from: linectr - 1, to: linectr }
        end

        srclines = { from: Integer($~[2]), to: Integer($~[2]) }
        msgs.push(TexLogParser::Message.new(message: msg, source_file: $~[3],
                                            source_lines: srclines, log_lines: loglines,
                                            level: :error))
        errors = true
      end
      linectr += 1
      lastline = line
    end

    { success: !errors, messages: msgs, log: log.join('').strip! }
  end
end

Extension.add BibTeX
