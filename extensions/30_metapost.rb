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

Dependency.new('mpost', :binary, [:extension, 'MetaPost'], :essential)

# TODO: document
class MetaPost < Extension
  def initialize
    super
    @name = 'MetaPost'
    @description = 'Compiles generated MetaPost files'

    @mp_files = []
  end

  def do?(time)
    time == 1 && job_size > 0
  end

  def job_size
    # Count the number of changed _.mp files
    # Store because a check for changed hashes in exec later would give false!
    # Append because job_size may be called multiple times before exec
    @mp_files += Dir.entries('.').delete_if do |f|
      (/\.mp$/ !~ f) || !HashManager.instance.files_changed?(f)
    end
    @mp_files.size

    # TODO: check for (non-)existing result? incorporate ir parameter?
  end

  def exec(time, progress)
    params = ParameterManager.instance

    # Command to process metapost files if necessary.
    mpost = '"mpost -tex=#{params[:engine]} -file-line-error -interaction=nonstopmode \"#{f}\" 2>&1"'

    # Run mpost for each job file
    log = [[], []]
    unless @mp_files.empty?
      # Run (latex) engine for each figure
      log = self.class.execute_parts(@mp_files, progress) do |f|
        compile(mpost, f)
      end.transpose
    end
    @mp_files = [] # reset for next round of checks

    # Log line numbers are wrong since every compile determines log line numbers
    # w.r.t. its own contribution. Later steps will only add the offset of the
    # whole metapost block, not those inside.
    offset = 0
    (0..(log[0].size - 1)).each do |i|
      unless log[0][i].empty?
        internal_offset = 3 # Stuff we print per plot before log excerpt (see :compile)
        log[0][i].map! do |m|
          LogMessage.new(m.type, m.srcfile, m.srcline,
                         unless m.logline.nil?
                           m.logline.map { |ll| ll + offset + internal_offset}
                         end,
                         m.msg, m.formatted? ? :fixed : :none)
        end
      end
      offset += log[1][i].count("\n")
    end

    log[0].flatten!
    errors = log[0].count { |m| m.type == :error }
    { success: errors <= 0, messages: log[0], log: log[1].join }
  end

  private

  def compile(cmd, f)
    params = ParameterManager.instance

    log = ''
    msgs = []

    # Run twice to get LaTeX bits right
    IO.popen(eval(cmd), &:readlines)
    lines = IO.popen(eval(cmd), &:readlines)
    output = lines.join('').strip

    log << "# #\n# #{f}\n\n"
    if output != ''
      log << output
      msgs += parse(lines, f)
    else
      log << 'No output from mpost, so apparently everything went fine!'
    end
    log << "\n\n"

    [msgs, log]
  end

  def parse(strings, file)
    msgs = []

    linectr = 1
    curmsg = nil
    curline = -1
    strings.each do |line|
      # Messages have the format
      #  ! message
      #  ...
      #  l.\d+ ...
      if /^! (.*)$/ =~ line
        curmsg = $LAST_MATCH_INFO[1].strip
        curline = linectr
      elsif !curmsg.nil? && /^l\.(\d+)/ =~ line
        msgs.push(LogMessage.new(:error, "#{ParameterManager.instance[:tmpdir]}/#{file}",
                                 [Integer($LAST_MATCH_INFO[1])], [curline, linectr],
                                 curmsg, :none))
        curmsg = nil
        curline = -1
      end
      linectr += 1
    end

    msgs
  end
end

Extension.add MetaPost
