# Copyright 2010-2018, Raphael Reitzig
#
# This file is part of chew.
#
# chew is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# chew is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with chew. If not, see <http://www.gnu.org/licenses/>.

require 'json'

module Chew
  module LogWriters
# TODO: document
    class Json
      include LogWriter
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
            summary:    {
              call:          "#{$PROGRAM_NAME} #{ARGV.join(' ')}",
              version:       VERSION,
              workDirectory: params[:jobpath],
              document:      params[:jobfile],
              runs:          [], # TODO
              rawLog: "#{params[:tmpdir]}/#{params[:log]}.full",
              counts: {
                error:   log.count(:error),
                warning: log.count(:warning),
                info:    log.count(:info)
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
            counts:   {
              error:   log.count(:error, source),
              warning: log.count(:warning, source),
              info:    log.count(:info, source)
            },
            messages: messages # TexLogParser::Message converts reasonably
          }
        end
      end
    end
  end
end
