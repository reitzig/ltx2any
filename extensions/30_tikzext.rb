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

ParameterManager.instance.addParameter(Parameter.new(
                                         :imagerebuild, 'ir', String, '', "Specify externalised TikZ images to rebuild, separated by ':'. Set to 'all' to rebuild all."
                                       ))

# TODO: document
class TikZExt < Extension
  def initialize
    super
    @name = 'TikZ externalization'
    @description = 'Compiles externalized TikZ images'
  end

  def do?(time)
    time == 1 && job_size.positive?
  end

  def job_size
    collect_pending[0].size
  end

  def exec(_time, progress)
    params = ParameterManager.instance

    # Collect all externalised figures
    figures, rebuildlog = collect_pending

    log = [[], []]
    unless figures.empty?
      # Run (latex) engine for each figure
      log = self.class.execute_parts(figures, progress) do |fig|
        compile(fig)
      end.transpose
    end

    # Log line numbers are wrong since every compile determines log line numbers
    # w.r.t. its own contribution. Later steps will only add the offset of the
    # whole tikzext block, not those inside.
    offset = 0
    (0..(log[0].size - 1)).each do |i|
      msg = ''
      if log[0][i].empty?
        msg = <<~MSG
          No messages for figure
            #{figures[i]}
          found.
        MSG
      else
        internal_offset = 5 # Stuff we print per figure before log excerpt (see :compile)
        log[0][i].map! do |m|
          m.log_lines&.update(m.log_lines) { |_, ll| ll + offset + internal_offset - 1 }
          m
        end

        msg = <<~MSG
          The following messages refer to figure
            #{figures[i]}.

        MSG
      end
      msg += <<~MSG
        See
          #{params[:tmpdir]}/#{figures[i]}.log
        for the full log.
      MSG
      log[0][i].unshift(TexLogParser::Message.new(message: msg, level: :info, preformatted: true))
      offset += log[1][i].count("\n")
    end

    log[0].flatten!
    errors = log[0].count { |m| m.level == :error }
    { success: errors <= 0, messages: rebuildlog[0] + log[0], log: rebuildlog[1] + log[1].join }
  end

  private

  def collect_pending
    params = ParameterManager.instance

    figures = []
    rebuildlog = [[], '']
    if File.exist?("#{params[:jobname]}.figlist")
      figures = File.readlines("#{params[:jobname]}.figlist").map do |fig|
        if fig.strip == ''
          nil
        else
          fig.strip
        end
      end.compact

      # Remove results of figures that we want to rebuild
      rebuild = []
      if params[:imagerebuild] == 'all'
        rebuild = figures
      else
        params[:imagerebuild].split(':').map(&:strip).each do |fig|
          if figures.include?(fig)
            rebuild.push(fig)
          else
            msg = "User requested rebuild of figure `#{fig}` which does not exist."
            rebuildlog[0].push(TexLogParser::Message.new(message: msg, level: :warning))
            rebuildlog[1] += "#{msg}\n\n"
          end
        end
      end

      figures.select! do |fig|
        !File.exist?("#{fig}.pdf") || rebuild.include?(fig)
      end
    end

    [figures, rebuildlog]
  end

  def compile(fig)
    params = ParameterManager.instance
    log = String.new
    log << "# #\n# Figure: #{fig}\n#   See #{params[:tmpdir]}/#{fig}.log for full log.\n\n"

    # Command to process externalised TikZ images if necessary.
    # Uses the following variables:
    # * $params["engine"] -- Engine used by the main job.
    # * params[:jobname] -- name of the main LaTeX file (without file ending)
    pdflatex = "#{params[:engine]} -shell-escape -file-line-error -interaction=batchmode " +
      "-jobname '#{fig}' " +
      "'\\\def\\\tikzexternalrealjob{#{params[:jobname]}}\\\input{#{params[:jobname]}}' " +
      '2>&1'

    # Run twice to clean up log?
    # IO::popen(pdflatex).readlines
    IO.popen(pdflatex, &:readlines)
    # Shell output does not contain error messages -> read log
    output = File.open("#{fig}.log", 'r') do |f|
      f.readlines.map { |s| Log.fix(s) }
    end

    # These seems to describe reliable boundaries of that part in the log
    # which deals with the processed TikZ figure.
    startregexp = /^\\openout\d+ = `#{fig}\.dpth'\.\s*$/
    endregexp = /^\[\d+\s*\]?$/

    # Cut out relevant part for raw log (heuristic)
    relevant_lines = output.drop_while do |line|
      startregexp !~ line
    end.take_while do |line|
      endregexp !~ line
    end.drop(1)
    string = relevant_lines.join.strip

    log << (string == '' ? 'No errors detected.' : "<snip>\n\n#{string}\n\n<snip>")

    # Parse whole log for messages (needed for filenames) but restrict
    # to messages from interesting part
    msgs = TexLogParser.new(relevant_lines).parse

    # Still necessary? Should get *some* error from the recursive call.
    # if ( !File.exist?("#{fig}.pdf") )
    #   log << "Fatal error on #{fig}. See #{$params["tmpdir"]}/#{fig}.log for details.\n"
    # end
    log << "\n\n"

    [msgs, log]
  end
end

Extension.add TikZExt
