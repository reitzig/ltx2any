# frozen_string_literal: true

# Copyright 2010-2015, Raphael Reitzig
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

class DaemonPrompt
  def self.run
    params = ParameterManager.instance
    command = getCommand
    while command.size.positive?
      begin
        case command[0]
        when :set
          if command.size < 3
            respond 'Please supply a parameter name and a value.'
          else
            value = command[2, command.size - 1].join(' ')
            params[command[1].to_sym] = value
            respond "Set parameter '#{command[1]}' to '#{params[command[1].to_sym]}'."
          end
        when :add
          if command.size < 3
            respond 'Please supply a parameter name and a value.'
          else
            value = command[2, command.size - 1].join(' ') # TODO: join with `:` instead?
            params.add(command[1].to_sym, value)
            respond "Changed parameter '#{command[1]}' to '#{params[command[1].to_sym]}'."
          end
        when :show
          respond "#{command[1]} = #{params[command[1].to_sym]}"
        when :clean
          FileUtils.rm_rf(params[:tmpdir])
          respond 'Temporary files deleted'
          if command.size > 1 && command[1].to_sym == :all
            FileUtils.rm("#{params[:log]}.#{params[:logformat]}") # TODO: may fail when MD fallback?
            respond 'Log file deleted'
            # TODO: remove result
          end
        when :run
          break
        when :quit
          raise SystemExit, 'User issued quit command'
        when :help
          respond 'Work in progress. Supports commands set, show, clean (partial), run and quit.'
        else
          respond "Command #{command[0]} unknown"
        end
      rescue ParameterException => e
        respond "Error: #{e.message}"
      end

      # TODO: process commands/options:
      #  open (log|result|source) -- open specified files
      #  set/add once <name> <value> -- sets parameter to value for one run
      #  listen -- commence listening for file changes (?)

      command = getCommand
    end

    #  Throw SystemExit for quitting.
    #  Return regularly for rerun.
    # TODO should we allow to return to listening? --> other Exception or return value
  end

  def self.respond(msg)
    puts "\t#{msg}"
    # TODO: add line breaking?
  end

  def self.getCommand
    print '> '
    command = gets.strip.split(/\s+/) # User may quit by hitting ^C at this point
    command[0] = if command.size.positive?
                   command[0].to_sym
                 else
                   :run
                 end
    command
  end
end
