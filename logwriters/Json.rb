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

require 'json'

# TODO: document
class Json < LogWriter
  class << self
    def name
      'JSON'
    end

    def description
      'Create a JSON file with all log messages.'
    end

    def to_sym
      :json
    end

    # Returns the name of the written file, or raises an exception
    # @param [Log] log
    # @param [String] jobname
    def write(log, jobname)
      params = ParameterManager.instance

      json_log = {
        summary: {
          call: "#{$PROGRAM_NAME} #{ARGV.join(' ')}",
          version: VERSION,
          workDirectory: params[:jobpath],
          document: params[:jobfile],
          runs: [], # TODO
          rawLog: "#{params[:tmpdir]}/#{params[:log]}.full",
          counts: {
            error: log.count(:error),
            warning: log.count(:warning),
            info: log.count(:info)
          }
        },
        categories: log.sources.map { |c| convert_category(c, log) }
      }

      target_file = "#{params[:log]}.json"
      File.open(target_file, 'w') { |f| f.write(JSON.pretty_generate(json_log)) }
      target_file
    end

    private

    # @param [String] source
    # @param [Log] log
    def convert_category(source, log)
      messages = log.messages_for(source)

      {
        name: source,
        call: "<not available yet>", # TODO
        counts: {
          error: log.count(:error, source),
          warning: log.count(:warning, source),
          info: log.count(:info, source)
        },
        messages: messages.map { |m| convert_message(m) }
      }
    end

    # @param [LogMessage] message
    # @return [Hash]
    def convert_message(message)
      result = {
        type: message.type.to_s,
        message: message.msg,
        logLines: {
          from: message.logline[0]
        },
        formatted: message.formatted?
      }

      result[:sourceFile] = message.srcfile unless message.srcfile.nil?
      result[:logLines][:to] = message.logline[1] if message.logline.count > 1

      unless message.srcline.nil?
        source_lines = {
          from: message.srcline[0]
        }
        source_lines[:to] = message.srcline[1] if message.srcline.count > 1
        result[:sourceLines] = source_lines
      end

      result
    end
  end
end

LogWriter.add Json