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

# TODO: Document
class HashManager
  include Singleton

  def initialize
    @hashes = {}
  end

  # Hashes the given string
  def self.hash(string)
    Digest::MD5.hexdigest(string)
    # TODO: SHA-256?
  end

  # Computes a hash of the given file.
  # Parameters drop_from and without are optional; if specified,
  # they have to be regexps.
  #
  # - If parameter drop_from is specified, all content in the file
  #   from its first match are dropped before hashing.
  # - If parameter without is specified, all lines matching it
  #   are dropped before hashing
  #
  # Important: drop_from is applied first!
  def self.hash_file(filename, drop_from: nil, without: nil)
    if !File.exist?(filename)
      nil
    elsif drop_from.nil? && without.nil?
      Digest::MD5.file(filename).to_s
    else
      string = File.read(filename)

      # Fix string encoding; regexp matching below may fail otherwise
      # TODO check if this is necessary with Ruby versions beyond 2.0.0
      unless string.valid_encoding?
        string = string.encode('UTF-16be',
                               invalid: :replace,
                               replace: '?').encode('UTF-8')
      end

      # Drop undesired prefix if necessary
      string = string.split(drop_from).first if !drop_from.nil? && drop_from.is_a?(Regexp)

      # Drop undesired lines if necessary
      if !without.nil? && without.is_a?(Regexp)
        lines = string.split("\n")
        lines.reject! { |l| l =~ without }
        string = lines.join("\n")
      end

      hash(string.strip)
    end
  end

  # Returns true if (and only if) any of the specified files has been
  # created, changed or deleted between this and the last call of
  # the method of which it was a parameter.
  def files_changed?(*files)
    result = false

    files.each do |f|
      # TODO: allow arrays with parameters for hash_file?
      if File.exist?(f)
        hash = self.class.hash_file(f)
        result = result || !@hashes.key?(f) || hash != @hashes[f]
        # puts "new or changed file #{f}" if !@@hashes.has_key?(f) || hash != @@hashes[f]
        @hashes[f] = hash
      elsif @hashes.key?(f)
        @hashes.remove(f)
        result = true
      end
    end

    result
  end

  # Reads hashes from a file in format
  #   filename,hash
  # Overwrites any hashes that are already known.
  def from_file(filename)
    return unless File.exist?(filename)

    File.open(filename, 'r') do |f|
      f.readlines.each do |l|
        parts = l.split(',')
        # Comma may appear as filename, so we have to make sure to only
        # use the last component as hash
        @hashes[parts.take(parts.size - 1).join(',').strip] = parts.last.strip
      end
    end
  end

  # Writes hashes to a file in format
  #   filename,hash
  # Overwrites existing file.
  def to_file(filename)
    File.open(filename, 'w') do |f|
      @hashes.each_pair do |k, v|
        f.write("#{k},#{v}\n")
      end
    end
  end

  def empty?
    @hashes.empty?
  end
end
