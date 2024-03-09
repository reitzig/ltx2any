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

# TODO: document
# @abstract
class LogWriter
  @@list = {}
  @@dependencies = DependencyManager.list(source: [:core, 'LogWriter'])

  # @param [LogWriter] lw
  def self.add(lw)
    @@list[lw.to_sym] = lw
  end

  # @return [Array<LogWriter>]
  def self.list
    @@list.values
  end

  # @return [LogWriter]
  def self.[](key)
    @@list[key]
  end

  # @return [String]
  def self.name
    raise NotImplementedError
  end

  # @return [String]
  def self.description
    raise NotImplementedError
  end

  # @return [Symbol]
  def self.to_sym
    raise NotImplementedError
  end

  def self.to_s
    name
  end

  # Returns the name of the written file, or raises an exception
  # @param [Log] log
  # @param [:error,:warning,:info]
  # @return [String]
  def self.write(log, level = :warning)
    raise NotImplementedError
  end

  def self.pls(count)
    if count == 1
      ''
    else
      's'
    end
  end

  def self.indent(s, indent)
    s.split(/\n+/).map { |line| (' ' * indent) + line }.join("\n")
  end

  def self.break_at_spaces(s, length, indent)
    words = s.split(/\s+/)

    res = ''
    line = ' ' * [0, indent - 1].max
    words.each do |w|
      newline = "#{line} #{w}"
      if newline.length > length
        res += "#{line}\n"
        line = (' ' * indent) + w
      else
        line = newline
      end
    end

    res + line
  end
end

# Load all extensions
Dir["#{BASEDIR}/#{LOGWDIR}/*.rb"].each do |f|
  load(f)
end

# Add log-writer-related parameters
[
  Parameter.new(:log, 'l', String, '"#{self[:user_jobname]}.log"',
                '(Base-)Name of log file'),
  Parameter.new(:logformat, 'lf', LogWriter.list.map(&:to_sym), :md,
                'The log format. Call with --logformats for a list.'),
  Parameter.new(:loglevel, 'll', %i[error warning info], :warning,
                "Set to 'error' to see only errors, to 'warning' to also see warnings, or to 'info' for everything.")
].each { |p| ParameterManager.instance.addParameter(p) }
