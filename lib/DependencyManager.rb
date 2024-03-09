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

class DependencyManager
  @@dependencies = []

  def self.more_recent(v1, v2)
    v1i = v1.gsub(/[^\d]/, '').to_i
    v2i = v2.gsub(/[^\d]/, '').to_i
    v1i > v2i ? v1 : v2
  end

  # which(cmd) :: string or nil
  #
  # Multi-platform implementation of "which".
  # It may be used with UNIX-based and DOS-based platforms.
  #
  # The argument can not only be a simple command name but also a command path
  # may it be relative or complete.
  #
  # From: http://stackoverflow.com/a/25563129/539599
  def self.which(cmd)
    raise ArgumentError.new("Argument not a string: #{cmd.inspect}") unless cmd.is_a?(String)
    return nil if cmd.empty?

    case RbConfig::CONFIG['host_os']
    when /cygwin/
      exts = nil
    when /dos|mswin|^win|mingw|msys/
      pathext = ENV.fetch('PATHEXT', nil)
      exts = pathext ? pathext.split(';').select { |e| e[0] == '.' } : ['.com', '.exe', '.bat']
    else
      exts = nil
    end
    if cmd[File::SEPARATOR] || (File::ALT_SEPARATOR && cmd[File::ALT_SEPARATOR])
      if exts
        ext = File.extname(cmd)
        if !ext.empty? && exts.any? { |e| e.casecmp(ext).zero? } && File.file?(cmd) && File.executable?(cmd)
          return File.absolute_path(cmd)
        end

        exts.each do |ext|
          exe = "#{cmd}#{ext}"
          return File.absolute_path(exe) if File.file?(exe) && File.executable?(exe)
        end
      elsif File.file?(cmd) && File.executable?(cmd)
        return File.absolute_path(cmd)
      end
    else
      paths = ENV.fetch('PATH', nil)
      paths = paths ? paths.split(File::PATH_SEPARATOR).select { |e| File.directory?(e) } : []
      if exts
        ext = File.extname(cmd)
        has_valid_ext = !ext.empty? && exts.any? { |e| e.casecmp(ext).zero? }
        paths.unshift('.').each do |path|
          if has_valid_ext
            exe = File.join(path, "#{cmd}")
            return File.absolute_path(exe) if File.file?(exe) && File.executable?(exe)
          end
          exts.each do |ext|
            exe = File.join(path, "#{cmd}#{ext}")
            return File.absolute_path(exe) if File.file?(exe) && File.executable?(exe)
          end
        end
      else
        paths.each do |path|
          exe = File.join(path, cmd)
          return File.absolute_path(exe) if File.file?(exe) && File.executable?(exe)
        end
      end
    end
    nil
  end

  def self.add(dep)
    raise "Illegal parameter #{dep}" unless dep.is_a?(Dependency)

    @@dependencies.push(dep)
  end

  def self.list(type: :all, source: :all, relevance: :all)
    @@dependencies.select do |d|
      (type == :all      || d.type == type           || (type.is_a?(Array) && type.include?(d.type))) \
   && (source == :all    || d.source == source       || (d.source.is_a?(Array) && d.source.include?(source))) \
   && (relevance == :all || d.relevance == relevance || (relevance.is_a?(Array) && relevance.include?(d.relevance)))
    end
  end

  def self.to_s
    @@dependencies.map { |d| d.to_s }.join("\n")
  end
end

class MissingDependencyError < StandardError; end

class Dependency
  def initialize(name, type, source, relevance, reason = '', version = nil)
    raise "Illegal dependency type #{type}" unless %i[binary file].include?(type)

    if source != :core && (!source.is_a?(Array) || !%i[core extension engine logwriter].include?(source[0]))
      raise "Illegal source #{source}"
    end

    raise "Illegal relevance #{relevance}" unless %i[recommended essential].include?(relevance)

    unless version.nil? || version.empty?
      # Should not happen in production
      # TODO: add version command to dependency?
      puts 'Developer warning: versions of binaries and files are not checked!'
    end

    @name = name
    @type = type
    @source = source.is_a?(Array) ? source : [source, '']
    @relevance = relevance
    @reason = reason
    @version = version
    @available = nil

    DependencyManager.add(self)
  end

  def available?
    if @available.nil?
      @available =
        case @type
        when :binary
          !DependencyManager.which(@name).nil?
        when :file
          File.exist?(@name)
        else
          # Should not happen in production
          raise "Illegal dependency type #{@type}"
        end
    end

    @available
  end

  def to_s
    "#{@type} #{@name} is #{@relevance} for #{@source.join(' ').strip}"
  end

  attr_reader :name, :type, :source, :relevance, :reason, :version

  def relevance=(value)
    raise "Illegal relevance #{value}" unless %i[recommended essential].include?(value)

    @relevance = value
  end
end
