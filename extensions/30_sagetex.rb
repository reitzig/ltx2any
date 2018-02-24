# Copyright 2010-2017, Raphael Reitzig
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

# TODO: document
class SageTeX < Extension
  def initialize
    super
    @name = 'SageTeX'
    @description = 'Processes SageMath code created by SageTeX'
  end

  def do?(time)
    params = ParameterManager.instance
    time == 1 &&
      File.exist?("#{params[:jobname]}.sagetex.sage") &&
      HashManager.instance.files_changed?("#{params[:jobname]}.sagetex.sage")
  end

  def exec(time, progress)
    params = ParameterManager.instance

    # Command to process SageMath code.
    sagemath = '"sagemath \"#{params[:jobname]}.sagetex.sage\" 2>&1"'

    f = IO::popen(eval(sagemath))
    log = f.readlines

    errors = parse(log)

    { success: errors.count <= 0, messages: errors, log: log.join('') }
  end

  private

  def parse(lines)
    messages = []

    lines << ''
    msg = nil
    linectr = 1
    lines.each { |line|
      if !msg.nil? && line.strip.empty?
        msg.logline << linectr - 1
        msg = nil
      elsif msg.nil? && line =~ /File "(.+)",\s+line (\d+)/
        msg = LogMessage.new(:warning, $~[1], [$~[2].to_i], [linectr], '', :fixed)
        messages << msg
      elsif line =~ /SyntaxError: \w+/
        msg.type = :error
        msg.logline << linectr
        msg.msg += line
        msg = nil
      elsif line =~ /sagetex\.VersionError:/
        msg.type = :error
      # TODO: what are other patterns?
      elsif !msg.nil?
        msg.msg += line
      end

      linectr += 1
    }

    messages
  end
end

Extension.add SageTeX
