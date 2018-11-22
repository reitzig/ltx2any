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

require 'optparse'

module Chew
  class << self
    def setup_opts
      @options = {}

      OptionParser.new do |opts|
        opts.banner = "Usage: #{NAME} [options] <file>"

        opts.on_tail('-h', '--help', 'Show this message') do
          puts opts
          exit
        end
        opts.on_tail('-v', '--version', 'Show version') do
          puts "#{NAME} #{VERSION}"
          puts "Copyright \u00A9 #{AUTHOR} #{YEAR}".encode('utf-8')
          puts 'This is free software; see the source for copying conditions.'
          puts 'There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.'
          exit
        end
        opts.on_tail('--list TYPE', String,
                     'List available TYPE components',
                     '  (extensions, engines, logformats, dependencies') do |type|
          case type
          when 'extensions'
            # TODO indicate which have unmet dependencies
            # TODO fix formatting
            # TODO details
            puts Chew::EXTENSIONS.map(&:to_s).join(', ')
          when 'engines'
            # TODO indicate which have unmet dependencies
            # TODO fix formatting
            # TODO details
            puts Chew::ENGINES.map(&:to_s).join(', ')
          when 'logformats'
            # TODO indicate which have unmet dependencies
            # TODO fix formatting
            # TODO details
            puts Chew::LOG_FORMATS.map(&:to_s).join(', ')
          when 'dependencies'
            puts DependencyManager.to_s # TODO make prettier
          else
            STDERR.puts "Invalid argument: #{type}"
            exit 1
          end
          exit
        end

        # TODO: Invoke ParameterManager

        begin
          opts.parse!
        rescue StandardError => e
          STDERR.puts e
          exit 1
        end

        if !@options[:input].is_a?(String) && STDIN.tty?
          STDERR.puts opts.help
          exit 1
        end
      end
    end
  end
end

# TODO: port details from below above?
# elsif args[0] == '--extensions'
#   puts 'Installed extensions in execution order:' # TODO change after toposorted-extension order!
#   maxwidth = Extension.list.map { |e| e.name.length }.max
#   Extension.list.each { |e|
#     puts "  #{e.name}#{' ' * (maxwidth - e.name.length)}\t#{e.description}"
#   }
#   return true
# elsif args[0] == '--engines'
#   puts 'Installed engines:'
#   maxwidth = Engine.list.map { |e| e.to_sym.to_s.length }.max
#   Engine.list.sort_by(&:name).each { |e|
#     if DependencyManager.list(source: [:engine, e.binary], relevance: :essential).all?(&:available?)
#       print "  #{e.to_sym}#{' ' * (maxwidth - e.to_sym.to_s.length)}\t#{e.description}"
#       if e.to_sym == params[:engine]
#         print ' (default)'
#       end
#       puts ''
#     end
#   }
#   return true
# elsif args[0] == '--logformats'
#   puts 'Available log formats:'
#   maxwidth = LogWriter.list.map { |lw| lw.to_sym.to_s.length }.max
#   LogWriter.list.sort_by(&:name).each { |lw|
#     if DependencyManager.list(source: [:logwriter, lw.to_sym], relevance: :essential).all?(&:available?)
#       print "  #{lw.to_sym}#{' ' * (maxwidth - lw.to_sym.to_s.length)}" +
#                 "\t#{lw.description}"
#       if lw.to_sym == params[:logformat]
#         print ' (default)'
#       end
#       puts ''
#     end
#   }
#   return true
