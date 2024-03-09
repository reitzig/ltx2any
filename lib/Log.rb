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

# TODO: Add list of runs with called command
# TODO: Add additional distinguisher to LMessage? E.g. the LaTeX package.

# TODO: Document
class Log
  def initialize
    @messages = {}
    @counts = { error: { total: 0 },
                warning: { total: 0 },
                info: { total: 0 } }
    # @level = :warning # or :error, :info
    @rawoffsets = nil
    @mode = :structured # or :flat
    @dependencies = DependencyManager.list(source: [:core, self.class.to_s])
  end

  # @param [:error,:warning,:info] level
  # @return [Hash<String, Array<(Symbol,Array<Message>,String)>]
  def only_level(level)
    # Write messages from engine first
    # (Since @messages contains only one entry per run engine/extension, this is fast.)
    keys = @messages.keys.select { |k| @messages[k][0] == :engine } +
           @messages.keys.select { |k| @messages[k][0] == :extension }

    # TODO: rewrite for efficiency: this should give an iterator without
    #      actually doing anything.
    keys.map do |k|
      msgs = @messages[k][1].select do |m|
        m.level == :error || # always show errors
          level == :info || # show everything at info level
          level == m.level # remaining case (warnings in :warning level)
      end

      { k => [@messages[k][0], msgs, @messages[k][2]] }
    end.reduce({}) { |res, e| res.merge!(e) }
  end

  # @param [String] source
  # @param [:error,:warning,:info] lowest_level
  # @return [Array<Message>]
  def messages_for(source, lowest_level = :info)
    only_level(lowest_level)[source][1]
  end

  attr_accessor :level # TODO: implement flat mode?

  # Parameters
  #  1. name of the source component (extension or engine)
  #  2. :engine or :extension
  #  3. List of Message objects
  #  4. Raw log/output
  def add_messages(source, sourcetype, msgs, raw)
    unless @messages.key?(source)
      @messages[source] = [sourcetype, [], '']
      @counts[:error][source] = 0
      @counts[:warning][source] = 0
      @counts[:info][source] = 0
    end

    @messages[source][1] += msgs
    @messages[source][2] += (raw.nil? ? '' : raw) # TODO: how can this ever be nil?
    %i[error warning info].each do |type|
      cnt = msgs.count { |e| e.level == type }
      @counts[type][source] += cnt
      @counts[type][:total] += cnt
    end

    @rawoffsets = nil
  end

  # @return [Bool]
  def has_messages?(source)
    @messages.key?(source)
  end

  # @param [String] source
  # @return [Array<Message>]
  def messages(source)
    @messages[source].clone
  end

  # @return [Bool]
  def empty?
    @messages.empty?
  end

  # @return [Array<String>]
  def sources
    @messages.keys
  end

  # @return [Int]
  def count(type, part = :total)
    @counts[type][part]
  end

  # Finishes this log. Do not try to add new messages after calling
  # this.
  def finish
    # Compute offsets in raw log
    _ = to_s # TODO: Compute smarter, without assembling the whole string

    # Adjust all log lines
    @messages.each_entry do |source, log_material|
      log_material[1].each do |msg|
        msg.log_lines&.update(msg.log_lines) { |_, i| i + @rawoffsets[source] }
      end
    end

    freeze
  end

  # Creates a string with the raw log messages.
  def to_s
    # TODO: it should be possible to determine offsets without building the log
    result = ''
    messages = only_level(:info)

    offset = 0
    @rawoffsets = {} unless frozen?
    messages.each_key do |source|
      result << "# # # # #\n"
      result << "# Start #{source}"
      result << "\n# # # # #\n\n"

      @rawoffsets[source] = offset + 4 unless frozen?
      result << messages[source][2]

      result << "\n\n# # # # #\n"
      result << "# Finished #{source}"
      result << "\n# # # # #\n\n"

      offset += 10 + messages[source][2].count("\n")
    end

    result
  end

  def self.fix(s)
    # Prevents errors when engines write illegal symbols to log.
    # Since the API changed between Ruby 1.8.x and 1.9, be
    # careful.
    if RUBY_VERSION.to_f < 1.9
      Iconv.iconv('UTF-8//IGNORE', 'UTF-8', s)
    else
      s.encode!(Encoding::UTF_16LE, invalid: :replace,
                                    undef: :replace,
                                    replace: '?').encode!(Encoding::UTF_8)
    end
  end
end
