# frozen_string_literal: true

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

# TODO: Document
class Markdown < LogWriter
  class << self
    def name
      'Markdown'
    end

    def description
      'Creates a human-readable text log using the Markdown format.'
    end

    def to_sym
      :md
    end

    # Returns the name of the written file, or raises an exception
    # TODO: de-spaghettify
    def write(log, level = :warning)
      params = ParameterManager.instance

      result = String.new
      result << "# Log for `#{params[:user_jobname]}`\n\n"
      messages = log.only_level(level)

      result << "**Disclaimer:**  \nThis is but a digest of the original log file.\n" \
                "For full detail, check out `#{params[:tmpdir]}/#{params[:log]}.full`.\n" \
                'In case we failed to pick up an error or warning, please ' \
                "[report it to us](https://github.com/akerbos/ltx2any/issues/new).\n\n"

      result << "We found **#{log.count(:error)} error#{pls(log.count(:error))}**, " \
                "*#{log.count(:warning)} warning#{pls(log.count(:warning))}* " \
                "and #{log.count(:info)} other message#{pls(log.count(:info))} in total.\n\n"

      # Write everything
      messages.each_key do |name|
        msgs = messages[name][1]

        result << "## `#{name}`\n\n"

        if msgs.empty?
          result << "Lucky you, `#{name}` had nothing to complain about!\n\n"

          if ((level == :warning && log.count(:info, name).positive?) ||
             (level == :error && (log.count(:info, name) + log.count(:warning, name)).positive?)) && (level != :info)
            result << 'Note, though, that this log only lists errors'
            result << ' and warnings' if level == :warning
            result << '. There were '
            result << "#{log.count(:warning, name)} warning#{pls(log.count(:warning, name))} and " if level == :error
            result << "#{log.count(:info, name)} information message#{pls(log.count(:info, name))} " \
                      "which you find in the full log.\n\n"
          end
        else
          result << "**#{log.count(:error, name)} error#{pls(log.count(:error, name))}**, " \
                    "*#{log.count(:warning, name)} warning#{pls(log.count(:warning, name))}* " \
                    "and #{log.count(:info, name)} other message#{pls(log.count(:info, name))}\n\n"

          msgs.each do |m|
            # Lay out for 80 characters width
            #  * 4 colums for list stuff
            #  * 11 columns for type + space
            #  * file:line flushed to the right after
            #  * The message, indented to the type stands out
            #  * Log line, flushed right
            result << (' *  ' +
                      { error: '**Error**',
                        warning: '*Warning*',
                        info: 'Info     ' }[m.level])
            unless m.source_file.nil?
              srcline = nil
              unless m.source_lines.nil?
                srcline = m.source_lines[:from].to_s
                unless m.source_lines[:to].nil? || m.source_lines[:to] == m.source_lines[:from]
                  srcline += "--#{m.source_lines[:to]}"
                end
              end

              srcfilelength = 76 - 9 - (srcline.nil? ? 0 : srcline.length + 1) - 2
              result << if m.source_file.length > srcfilelength
                          "  `...#{m.source_file[m.source_file.length - srcfilelength + 5, m.source_file.length]}"
                        else
                          (' ' * (srcfilelength - m.source_file.length)) + "`#{m.source_file}"
                        end
              result << ":#{srcline}" unless srcline.nil?
              result << '`'
            end
            result << "\n\n"
            result << if m.preformatted
                        "#{indent(m.message.strip, 8)}\n\n"
                      else
                        "#{break_at_spaces(m.message.strip, 68, 8)}\n\n"
                      end
            next if m.log_lines.nil?

            # We have line offset in the raw log!
            logline = m.log_lines[:from].to_s
            logline += "--#{m.log_lines[:to]}" unless m.log_lines[:to].nil? || m.log_lines[:to] == m.log_lines[:from]
            result << ("#{' ' * (80 - (6 + logline.length))}`log:#{logline}`\n\n")
          end
        end
      end

      target_file = "#{params[:log]}.md"
      File.write(target_file, result)
      target_file
    end
  end
end

LogWriter.add Markdown
