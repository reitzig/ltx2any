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
class LogWriter
  @@list = {}
  @@dependencies = DependencyManager.list(source: [:core, 'LogWriter'])

  def self.add(lw)
    @@list[lw.to_sym] = lw
  end

  def self.list
    @@list.values
  end

  def self.[](key)
    @@list[key]
  end

  def self.name
    raise 'subclass this!'
  end

  def self.description
    raise 'Subclass this!'
  end

  def self.to_sym
    raise 'Subclass this!'
  end

  def self.to_s
    name
  end

  # Returns the name of the written file, or raises an exception
  def self.write(log, level = :warning)
    raise 'Subclass this!'
  end

  protected

  def self.pls(count)
    if count == 1
      ''
    else
      's'
    end
  end

  def self.indent(s, indent)
    s.split("\n").map { |line| (' ' * indent) + line }.join("\n")
  end

  def self.break_at_spaces(s, length, indent)
    words = s.split(/\s+/)

    res = ''
    line = ' ' * [0, indent - 1].max
    words.each do |w|
      newline = line + ' ' + w
      if newline.length > length
        res += line + "\n"
        line = (' ' * indent) + w
      else
        line = newline
      end
    end

    res + line
  end
end

# Load all extensions
Dir["#{BASEDIR}/#{LOGWDIR}/*.rb"].sort.each do |f|
  load(f)
end

# Add log-writer-related parameters
[
  Parameter.new(:log, 'l', String, '"#{self[:user_jobname]}.log"',
                '(Base-)Name of log file'),
  Parameter.new(:logformat, 'lf', LogWriter.list.map(&:to_sym), :md,
                'The log format. Call with --logformats for a list.'),
  Parameter.new(:loglevel, 'll', [:error, :warning, :info], :warning,
                "Set to 'error' to see only errors, to 'warning' to also see warnings, or to 'info' for everything.")
].each { |p| ParameterManager.instance.addParameter(p) }