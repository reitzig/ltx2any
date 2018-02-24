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
  def self.name
    'Markdown'
  end

  def self.description
    'Creates a human-readable text log using the Markdown format.'
  end

  def self.to_sym
    :md
  end

  # Returns the name of the written file, or raises an exception
  def self.write(log, level = :warning)
    # TODO: compute rawoffsets in Log
    log.to_s if log.rawoffsets.nil? # Determines offsets in raw log

    params = ParameterManager.instance

    result = "# Log for `#{params[:user_jobname]}`\n\n"
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

        if (level == :warning && log.count(:info, name) > 0) ||
           (level == :error && log.count(:info, name) + log.count(:warning, name) > 0)
          if level != :info
            result << 'Note, though, that this log only lists errors'
            result << ' and warnings' if level == :warning
            result << '. There were '
            if level == :error
              result << "#{log.count(:warning, name)} warning#{pls(log.count(:warning, name))} and "
            end
            result << "#{log.count(:info, name)} information message#{pls(log.count(:info, name))} " \
                      "which you find in the full log.\n\n"
          end
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
          result << ' *  ' +
                    { error: '**Error**',
                      warning: '*Warning*',
                      info: 'Info     ' }[m.type]
          unless m.srcfile.nil?
            srcline = nil
            srcline = m.srcline.join('--') unless m.srcline.nil?
            srcfilelength = 76 - 9 - (!srcline.nil? ? srcline.length + 1 : 0) - 2
            result << if m.srcfile.length > srcfilelength
                        "  `...#{m.srcfile[m.srcfile.length - srcfilelength + 5, m.srcfile.length]}"
                      else
                        (' ' * (srcfilelength - m.srcfile.length)) + "`#{m.srcfile}"
                      end
            result << ":#{srcline}" unless srcline.nil?
            result << '`'
          end
          result << "\n\n"
          result << if m.formatted?
                      indent(m.msg.strip, 8) + "\n\n"
                    else
                      break_at_spaces(m.msg.strip, 68, 8) + "\n\n"
                    end
          next if m.logline.nil?
          # We have line offset in the raw log!
          logline = m.logline.map { |i| i + log.rawoffsets[name] }.join('--')
          result << (' ' * (80 - (6 + logline.length))) + '`log:' + logline + "`\n\n\n"
        end
      end
    end

    target_file = "#{params[:log]}.md"
    File.open(target_file, 'w') { |f| f.write(result) }
    target_file
  end
end

LogWriter.add Markdown
