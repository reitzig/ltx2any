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

require 'rubygems'

class DependencyManager
  private
    @@dependencies = {}
    # Format: [name, (:gem|:binary|:file) => {
    #   :relevance => (:essential|:recommended)
    #   :reasons   => [*string]
    #   :version   => ">=..."
    # }

    def self.more_recent(v1, v2)
      v1i = v1.gsub(/[^\d]/, "").to_i
      v2i = v2.gsub(/[^\d]/, "").to_i
      return v1i > v2i ? v1 : v2
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
        pathext = ENV['PATHEXT']
        exts = pathext ? pathext.split(';').select{ |e| e[0] == '.' } : ['.com', '.exe', '.bat']
      else
        exts = nil
      end
      if cmd[File::SEPARATOR] or (File::ALT_SEPARATOR and cmd[File::ALT_SEPARATOR])
        if exts
          ext = File.extname(cmd)
          if not ext.empty? and exts.any?{ |e| e.casecmp(ext).zero? } \
          and File.file?(cmd) and File.executable?(cmd)
            return File.absolute_path(cmd)
          end
          exts.each do |ext|
            exe = "#{cmd}#{ext}"
            return File.absolute_path(exe) if File.file?(exe) and File.executable?(exe)
          end
        else
          return File.absolute_path(cmd) if File.file?(cmd) and File.executable?(cmd)
        end
      else
        paths = ENV['PATH']
        paths = paths ? paths.split(File::PATH_SEPARATOR).select{ |e| File.directory?(e) } : []
        if exts
          ext = File.extname(cmd)
          has_valid_ext = (not ext.empty? and exts.any?{ |e| e.casecmp(ext).zero? })
          paths.unshift('.').each do |path|
            if has_valid_ext
              exe = File.join(path, "#{cmd}")
              return File.absolute_path(exe) if File.file?(exe) and File.executable?(exe)
            end
            exts.each do |ext|
              exe = File.join(path, "#{cmd}#{ext}")
              return File.absolute_path(exe) if File.file?(exe) and File.executable?(exe)
            end
          end
        else
          paths.each do |path|
            exe = File.join(path, cmd)
            return File.absolute_path(exe) if File.file?(exe) and File.executable?(exe)
          end
        end
      end
      nil
    end

  public
  
  def self.add(name, type, relevance=:recommended, reason="", version=">=0")
    if ( !@@dependencies.has_key?([name, type]) )
      @@dependencies[[name, type]] = { :relevance => relevance, :reasons => [reason], :version => version }
    elsif ( @@dependencies[[name, type]][:relevance] == relevance )
      @@dependencies[[name, type]][:reasons].push(reason)
      @@dependencies[[name, type]][:version] = more_recent(@@dependencies[[name, type]][:version], version)
    elsif ( @@dependencies[[name, type]][:relevance] == :recommended && relevance == :essential )
      @@dependencies[[name, type]][:relevance] = :essential
      @@dependencies[[name, type]][:reasons] = [reason]
      @@dependencies[[name, type]][:version] = more_recent(@@dependencies[[name, type]][:version], version)
    end

    if ( type != :gem && version != ">=0" )
      # Should not happen in production
      puts "Developer warning: versions of binaries and files are not checked!"
    end
  end

  def self.make_essential(name, type)
    if ( @@dependencies.has_key?([name, type]) )
      @@dependencies[[name, type]][:relevance] = :essential
    end
  end

  def self.load_essentials
    @@dependencies.each_key { |k|
      if ( @@dependencies[k][:relevance] == :essential && !available?(k[0], k[1]) )
        required_version = ""
        if ( k[1] == :gem && @@dependencies[k][:version] != ">=0" )
          required_version = ", version #{@@dependencies[k][:version]}"
        end
        raise StandardError.new("Essential dependency #{k[0]} (#{k[1].to_s}#{required_version}) unfulfilled")
      end
    }
  end

  def self.available?(name, type)
    if ( type == :gem )
      begin
        gem "#{name}"
        require name
        return true
      rescue Gem::LoadError
        return false
      end
    elsif ( type == :binary )
      return which(name) != nil
    elsif ( type == :file )
      return File.exists?(name)
    else
      # Should not happen in production
      puts "Developer warning: illegal dependency type #{type}"
    end
  end

  def self.to_s
    res = ""
    
    [[:gem, "gems"], [:binary, "binaries"], [:file, "files"]].each { |part|
      remainder = @@dependencies.each_key.select { |k| k[1] == part[0] }
      if ( !remainder.empty? )
        res += "  Required #{part[1]}:\n"
        remainder.each { |k|
          version = ""
          if ( @@dependencies[k][:version] != ">=0" )
            version = "#{@@dependencies[k][:version]}, "
          end
          res += "\t#{k[0]} (#{version}#{@@dependencies[k][:relevance]})"
          if ( !available?(*k) )
            missing = "missing"
            missing.upcase! if @@dependencies[k][:relevance] == :essential
            res += "\t\t\t\t#{missing}"
          end
          res += "\n"
        }
      end
    }

    return res
  end
end
