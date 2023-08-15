# frozen_string_literal: true

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
      options = {}

      OptionParser.new do |opts|
        opts.banner = "Usage: #{NAME} [options] <file>"

        # # # # # # # # #
        # CLI help
        # # # # # # # # #

        opts.on_tail('-h', '--help', 'Show this message') do
          puts opts
          exit
        end

        opts.on_tail('-v', '--version', 'Show version') do
          puts "#{NAME} #{VERSION}"
          puts "Copyright \u00A9 #{AUTHORS.join(', ')} #{YEAR}".encode('utf-8')
          puts 'This is free software; see the source for copying conditions.'
          puts 'There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.'
          exit
        end

        opts.on_tail('--list TYPE', String,
                     'List available TYPE components',
                     '  (extensions, engines, logformats, dependencies)') do |type|
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
            puts Chew::ENGINES.map { |e| "#{e.to_sym}\t#{e.description}" }.join("\n")
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

        # # # # # # # # #
        # Functional Parameters
        # # # # # # # # #

        options[:engine] = :lualatex
        opts.on('-e ENGINE', '--engine ENGINE', ENGINES.map(&:to_sym), 'Select engine') do |engine|
          ParameterManager.instance[:engine] = engine.to_sym # TODO: Decide what the role of ParameterManager is to be
          options[:engine] = engine.to_sym
        end

        # TODO: Invoke ParameterManager
        #   or else, how to implement hooks? Is that even a good model?

        begin
          opts.parse!
        rescue StandardError => e
          STDERR.puts e
          exit 1
        end

        unless ARGV.empty?
          # TODO: refactor
          # Check for input file first
          # Try to find an existing file by attaching common endings
          original = ARGV.first
          endings = ['tex', 'ltx', 'latex', '.tex', '.ltx', '.latex']
          jobfile = original
          while !File.exist?(jobfile) || File.directory?(jobfile)
            if endings.empty?
              raise ParameterException.new("No input file fitting #{original} exists.")
            end

            jobfile = "#{original}#{endings.pop}"
          end
          # TODO: do basic checks as to whether we really have a LaTeX file?

          ParameterManager.instance.addParameter(Chew::Parameter.new(:jobpath, nil, String, File.dirname(File.expand_path(jobfile)),
                                     'Absolute path of source directory'))
          ParameterManager.instance.addHook(:tmpdir) do |key, val|
            if self[:jobpath].start_with?(File.expand_path(val))
              raise Chew::ParameterException.new('Temporary directory may not contain job directory.')
            end
          end
          ParameterManager.instance.addParameter(Chew::Parameter.new(:jobfile, nil, String, File.basename(jobfile), 'Name of the main input file'))
          ParameterManager.instance.addParameter(Chew::Parameter.new(:jobname, nil, String, /\A(.+?)\.\w+\z/.match(ParameterManager.instance[:jobfile])[1],
                                     'Internal job name, in particular name of the main file and logs.'))
          ParameterManager.instance.addParameter(Chew::Parameter.new(:user_jobname, 'j', String, '"#{ParameterManager.instance[:jobname]}"',
                        'Job name, in particular name of the resulting file'))
          ParameterManager.instance.set(:user_jobname, ParameterManager.instance[:jobname]) if ParameterManager.instance[:user_jobname].nil?
          options[:input] = jobfile
        end

        if !options[:input].is_a?(String) && STDIN.tty?
          STDERR.puts opts.help
          exit 1
        end
      end

      options # TODO: Freeze? How to implement hooks?
    end
  end
end

# TODO: Port to opt-parser

# Add engine-related parameters
# Chew::ParameterManager.instance.addParameter(Chew::Parameter.new(
#   :engine, 'e', Chew::ENGINES.map(&:to_sym), :pdflatex,
#   'The output engine. Call with --engines for a list.'))
# ParameterManager.instance.addParameter(Parameter.new(
#   :enginepar, 'ep', String, '',
#   'Parameters passed to the engine, separated by spaces.'))
# ParameterManager.instance.addParameter(Parameter.new(
#   :engineruns, 'er', Integer, 0,
#   'How often the LaTeX engine runs. Values smaller than one will cause it to run until the resulting file no longer changes. May not apply to all engines.'))
#
# # Add log-writer-related parameters
# [
#   Parameter.new(:log, 'l', String, '"#{self[:user_jobname]}.log"',
#                 '(Base-)Name of log file'),
#   Parameter.new(:logformat, 'lf', Chew::LOG_FORMATS.map(&:to_sym), :md,
#                 'The log format. Call with --logformats for a list.'),
#   Parameter.new(:loglevel, 'll', [:error, :warning, :info], :warning,
#                 "Set to 'error' to see only errors, to 'warning' to also see warnings, or to 'info' for everything.")
# ].each { |p| ParameterManager.instance.addParameter(p) }

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
