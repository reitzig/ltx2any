# Copyright 2010-2016, Raphael Reitzig
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

DependencyManager.add('parallel', :gem, :recommended, "faster execution", ">=1.4.1")

class Extension
  @@list = {}

  def self.add(e)
    @@list[e.to_sym] = e
  end

  def self.list
    return @@list.values
  end

  def self.[](key)
    return @@list[key]
  end

  def self.to_sym
    self.new.to_sym
  end

  def initialize
    @name = "Dummy name"
    @description = "Dummy description"
  end

  # Hacky hack? Need to refactor this
  def self.name
    self.new.name
  end

  def self.description
    self.new.description
  end

  if ( !DependencyManager.available?('parallel', :gem) )
    # Define skeleton class for graceful sequential fallback
    module Parallel
      class << self
        def each(hash, options={}, &block)
          hash.each { |k,v|
            block.call(k, v)
            options[:finish].call(nil, nil, nil)
          }
          array
        end
      end
    end
  end

  # Wrap execution of many items
  def self.execute_parts(jobs, when_done, &block)
    parallel = DependencyManager.available?('parallel', :gem)

    Parallel.map(jobs, :finish  => lambda { |a,b,c| when_done.call }) { |job|
      begin
        block.call(job)
      rescue Interrupt
        raise Interrupt if !parallel # Sequential fallback needs exception!
      rescue => e
        Output.instance.msg("\tAn error occurred: #{e.to_s}")
        # TODO Should we break? Let's see what kinds of errors we get...
      end
    }
    # TODO do we have to care about Parallel::DeadWorker?
  end

  # Parameters
  # - time: one of :before, :after or a positive integer
  # - output: an instance of Output
  # - log: an instance of Log
  def self.run_all(time, output, log)
    list.each { |e|
      e = e.new
      if ( e.do?(time) ) # TODO check dependencies here?
        progress, stop = output.start("#{e.name} running", e.job_size)
        r = e.exec(time, progress)
        stop.call(if r[0] then :success else :error end)
        log.add_messages(e.name, :extension, r[1], r[2])
      end
    }
  end

  public
    def do?(time)
      false
    end

    def job_size
      return 1
    end

    def exec(time, progress)
      return [true, "No execution code, need to overwrite!"]
    end

    def to_s
      @name
    end

    def to_sym
      self.class.name.downcase.to_sym
    end

    attr_accessor :name, :description

  protected
    attr_reader :params
    attr_writer :name, :description
end

# Load all extensions
Dir["#{BASEDIR}/#{EXTDIR}/*.rb"].sort.each { |f|
  if ( !(/^\d\d/ !~ File.basename(f)) )
    load(f)
  end
}
