# frozen_string_literal: true

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

require 'English'
Dependency.new('makeindex', :binary, [:extension, 'makeindex'], :essential)

# TODO: document
class MakeIndex < Extension
  def initialize
    super

    @name = 'makeindex'
    @description = 'Creates an index'
  end

  def do?(time)
    return false unless time == 1

    params = ParameterManager.instance

    File.exist?("#{params[:jobname]}.idx") &&
      (!File.exist?("#{params[:jobname]}.ind") |
       HashManager.instance.files_changed?("#{params[:jobname]}.idx")
        # NOTE: non-strict OR so that hashes are computed for next run
      )
  end

  def exec(_time, _progress)
    params = ParameterManager.instance

    version = :default
    mistyle = nil
    Dir['*.ist'].each do |f|
      version = :styled
      mistyle = f
    end

    # Command to create the index if necessary. Provide two versions,
    # one without and one with stylefile
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    # * mistyle -- name of the makeindex style file (with file ending)
    makeindex = { default: "makeindex -q '#{params[:jobname]}' 2>&1",
                  styled: "makeindex -q -s \"#{mistyle}\" '#{params[:jobname]}' 2>&1" }
    # Even in quiet mode, some critical errors (e.g. regarding -g)
    # only end up in the error stream, but not in the file. Doh.
    #
    log1 = []
    IO.popen(makeindex[version]) do |f|
      log1 = f.readlines
    end

    log2 = []
    File.open("#{params[:jobname]}.ilg", 'r') do |f|
      log2 = f.readlines
    end

    log = [log2[0]] + log1 + log2[1, log2.length]

    msgs = []
    current = []
    linectr = 1
    errors = false
    log.each do |line|
      if /^!! (.*?) \(file = (.+?), line = (\d+)\):$/ =~ line
        current = [:error, $LAST_MATCH_INFO[2], { from: Integer($LAST_MATCH_INFO[3]), to: Integer($LAST_MATCH_INFO[3]) },
                   { from: linectr, to: linectr }, "#{$LAST_MATCH_INFO[1]}: "]
        errors = true
      elsif /^## (.*?) \(input = (.+?), line = (\d+); output = .+?, line = \d+\):$/ =~ line
        current = [:warning, $LAST_MATCH_INFO[2], { from: Integer($LAST_MATCH_INFO[3]), to: Integer($LAST_MATCH_INFO[3]) },
                   { from: linectr, to: linectr }, "#{$LAST_MATCH_INFO[1]}: "]
      elsif current != [] && /^\s+-- (.*)$/ =~ line
        current[3][:to] = linectr
        msgs.push(TexLogParser::Message.new(message: current[4] + $LAST_MATCH_INFO[1].strip,
                                            source_file: current[1], source_lines: current[2],
                                            log_lines: current[3], level: current[0]))
        current = []
      elsif /Option -g invalid/ =~ line
        msgs.push(TexLogParser::Message.new(message: line.strip,
                                            log_lines: { from: linectr, to: linectr }, level: :error))
        errors = true
      elsif /Can't create output index file/ =~ line
        msgs.push(TexLogParser::Message.new(message: line.strip,
                                            log_lines: { from: linectr, to: linectr }, level: :error))
        errors = true
      end
      linectr += 1
    end

    { sucess: !errors, messages: msgs, log: log.join.strip! }
  end
end

Extension.add MakeIndex
