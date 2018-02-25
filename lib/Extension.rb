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

class Extension
  @@list = {}
  @@dependencies = DependencyManager.list(source: [:core, 'Extension'])

  def self.add(e)
    @@list[e.to_sym] = e
  end

  def self.list
    @@list.values
  end

  def self.[](key)
    @@list[key]
  end

  def self.to_sym
    new.to_sym
  end

  def initialize
    @name = 'Dummy name'
    @description = 'Dummy description'
  end

  # Hacky hack? Need to refactor this
  def self.name
    new.name
  end

  def self.description
    new.description
  end

  unless @@dependencies.all?(&:available?)
    # Define skeleton class for graceful sequential fallback
    module Parallel
      class << self
        # TODO: implement map
        # TODO test this!
        def each(hash, options = {}, &block)
          hash.each do |k, v|
            block.call(k, v)
            options[:finish].call(nil, nil, nil)
          end
          array
        end
      end
    end
  end

  # Wrap execution of many items
  def self.execute_parts(jobs, when_done, &block)
    Parallel.map(jobs, finish: ->(_, _, _) { when_done.call }) do |job|
      begin
        block.call(job)
      rescue Interrupt
        raise Interrupt unless parallel # Sequential fallback needs exception!
      rescue => e
        Output.instance.msg("\tAn error occurred: #{e.to_s}")
        # TODO: Should we break? Let's see what kinds of errors we get...
      end
    end
    # TODO: do we have to care about Parallel::DeadWorker?
  end

  # Parameters
  # - time: one of :before, :after or a positive integer
  # - output: an instance of Output
  # - log: an instance of Log
  def self.run_all(time, output, log)
    list.each do |e|
      e = e.new
      next unless e.do?(time)

      # TODO: make dep check more efficient
      dependencies = DependencyManager.list(source: [:extension, e.name], relevance: :essential)
      if dependencies.all?(&:available?)
        progress, stop = output.start("#{e.name} running", e.job_size)
        r = begin
          e.exec(time, progress)
        rescue NotImplementedError
          { success: true,
            messages: ['No execution code, need to overwrite!'],
            log: 'No execution code, need to overwrite!' }
        end
        stop.call(r[:success] ? :success : :error)
        log.add_messages(e.name, :extension, r[:messages], r[:log])
      else
        # TODO: log message?
        output.separate.error('Missing dependencies:', *dependencies.reject(&:available?).map(&:to_s))
      end
    end
  end

  public

  # @abstract
  def do?(time)
    false
  end

  # @abstract
  def job_size
    1
  end

  # @abstract
  def exec(time, progress)
    raise NotImplementedError
  end

  def to_s
    @name
  end

  def to_sym
    self.class.name.downcase.to_sym
  end

  attr_reader :name, :description

  protected

  attr_writer :name, :description
end

# Load all extensions
Dir["#{BASEDIR}/#{EXTDIR}/*.rb"].sort.each do |f|
  load(f) if /^\d\d/ =~ File.basename(f)
end
