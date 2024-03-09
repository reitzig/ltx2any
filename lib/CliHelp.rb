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

class CliHelp
  include Singleton

  def initialize
    @hashes = {}
  end

  def provideHelp(args)
    params = ParameterManager.instance

    # Check for help/usage commands
    if args.empty? || /--help|--h/ =~ args[0]
      puts "\nUsage: "
      puts "  #{NAME} [options] inputfile\tNormal execution (see below)"
      puts "  #{NAME} --extensions\t\tList of extensions"
      puts "  #{NAME} --engines\t\tList of target engines"
      puts "  #{NAME} --logformats\t\tList of log formats"
      puts "  #{NAME} --dependencies\tList of dependencies"
      puts "  #{NAME} --version\t\tPrints version information"
      puts "  #{NAME} --help\t\tThis message"

      puts "\nOptions:"
      # params.keys.sort.each { |key|
      #  puts "  -#{key}\t#{if ( params[key][0] != nil ) then codes[key][0] end}\t#{params[key]}"
      # }
      params.user_info.each do |a|
        puts "  -#{a[:code]}\t#{a[:help]}"
      end

      # TODO: output unsatisfied dependencies

      true
    elsif args[0] == '--extensions'
      puts 'Installed extensions in execution order:' # TODO: change after toposorted-extension order!
      maxwidth = Extension.list.map { |e| e.name.length }.max
      Extension.list.each do |e|
        puts "  #{e.name}#{' ' * (maxwidth - e.name.length)}\t#{e.description}"
      end
      true
    elsif args[0] == '--engines'
      puts 'Installed engines:'
      maxwidth = Engine.list.map { |e| e.to_sym.to_s.length }.max
      Engine.list.sort_by(&:name).each do |e|
        next unless DependencyManager.list(source: [:engine, e.binary], relevance: :essential).all?(&:available?)

        print "  #{e.to_sym}#{' ' * (maxwidth - e.to_sym.to_s.length)}\t#{e.description}"
        print ' (default)' if e.to_sym == params[:engine]
        puts ''
      end
      true
    elsif args[0] == '--logformats'
      puts 'Available log formats:'
      maxwidth = LogWriter.list.map { |lw| lw.to_sym.to_s.length }.max
      LogWriter.list.sort_by(&:name).each do |lw|
        next unless DependencyManager.list(source: [:logwriter, lw.to_sym], relevance: :essential).all?(&:available?)

        print "  #{lw.to_sym}#{' ' * (maxwidth - lw.to_sym.to_s.length)}" \
              "\t#{lw.description}"
        print ' (default)' if lw.to_sym == params[:logformat]
        puts ''
      end
      true
    elsif args[0] == '--dependencies'
      puts DependencyManager # TODO: make prettier?
      true
    elsif args[0] == '--version'
      puts "#{NAME} #{VERSION}"
      puts "Copyright \u00A9 #{AUTHOR} #{YEAR}".encode('utf-8')
      puts 'This is free software; see the source for copying conditions.'
      puts 'There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.'
      true
    else # No help requested
      false
    end
  end
end
