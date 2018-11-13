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

require 'singleton'

class ParameterManager
  include Singleton

  # TODO: Make it so that keys are (also) "long" codes as fas as users are concerned. Interesting for DaemonPrompt!
  # TODO: add Array type (for -i -ir -ep ...)
  def initialize
    @values = {}
    @hooks = {}
    @code2key = {}
    @processed = false

    # @frozen_copy = nil
    # @copy_dirty = false
    # frozenCopy()
  end

  public

  def addParameter(p)
    if @processed
      raise ParameterException.new('Can not add parameters after CLI input has been processed.')
    end

    unless p.is_a?(Parameter)
      raise ParameterException.new("Can not add object of type #{p.class} as parameter.")
    end

    if @values.key?(p.key)
      raise ParameterException.new("Parameter #{p.key} already exists.")
    end

    @values[p.key] = p
    @code2key[p.code] = p.key
    @hooks[p.key] = [] unless @hooks.key?(p.key)
  end

  def processArgs(args)
    # Check for input file first
    # Try to find an existing file by attaching common endings
    original = ARGV.last
    endings = ['tex', 'ltx', 'latex', '.tex', '.ltx', '.latex']
    jobfile = original
    while !File.exist?(jobfile) || File.directory?(jobfile)
      if endings.empty?
        raise ParameterException.new("No input file fitting #{original} exists.")
      end

      jobfile = "#{original}#{endings.pop}"
    end
    # TODO: do basic checks as to whether we really have a LaTeX file?

    addParameter(Parameter.new(:jobpath, nil, String, File.dirname(File.expand_path(jobfile)),
                               'Absolute path of source directory'))
    addHook(:tmpdir) do |key, val|
      if self[:jobpath].start_with?(File.expand_path(val))
        raise ParameterException.new('Temporary directory may not contain job directory.')
      end
    end
    addParameter(Parameter.new(:jobfile, nil, String, File.basename(jobfile), 'Name of the main input file'))
    addParameter(Parameter.new(:jobname, nil, String, /\A(.+?)\.\w+\z/.match(self[:jobfile])[1],
                               'Internal job name, in particular name of the main file and logs.'))
    set(:user_jobname, self[:jobname]) if self[:user_jobname].nil?

    # Read in parameters
    # TODO use/build proper CLI and parameter handler?
    i = 0
    while i < ARGV.length - 1
      p = /\A-(\w+)\z/.match(ARGV[i])
      if p.nil?
        raise ParameterException.new("Don't know what to do with parameter #{ARGV[i]}.")
      end

      code = p[1]
      key = @code2key[code]

      unless @values.key?(key)
        raise ParameterException.new("Parameter -#{code} does not exist.")
      end

      if @values[key].type == Boolean
        set(key, :true)
        i += 1
      else
        val = ARGV[i+1]
        unless i + 1 < ARGV.length - 1
          raise ParameterException.new("No value for parameter -#{code}.")
        end

        set(key, val) # Does all the checking and converting
        i += 2
      end
    end

    # Evaluate remaining defaults that need to/can be evaluated
    # TODO Parameter values now contain user input. Security risk?
    keys.each do |key|
      val = @values[key].value
      next unless !val.nil? && val.is_a?(String) && !val.empty?

      begin
        @values[key].value = eval(val)
      rescue Exception => e
        # Leave value unchanged
        # puts "From eval on #{key}: #{e.message}"
      end
    end

    if jobfile.nil?
      raise ParameterException.new('Please provide an input file. Call with --help for details.')
    end

    @processed = true
  end

  def [](key)
    if @values.key?(key)
      @values[key].value
    else
      nil
    end
  end

  def []=(key, val)
    set(key, val, false)
  end

  def set(key, val, once = false) # TODO: implement "once" behaviour
    # TODO allow for proper validation functions?
    # TODO fall back to defaults instead of killing?
    unless @values.key?(key)
      raise ParameterException.new("Parameter #{key} does not exist.")
    end
    code = @values[key].code

    if @values[key].type == String
      @values[key].value = val.strip
    elsif @values[key].type == Integer
      if val.is_a?(Integer)
        @values[key].value = val
      elsif /\d+/ =~ val
        @values[key].value = val.to_i
      else
        raise ParameterException.new("Parameter -#{code} requires an integer ('#{val}' given).")
      end
    elsif @values[key].type == Float
      if val.is_a?(Float)
        @values[key].value = val
      elsif /\d+(\.\d+)?/ =~ val
        @values[key].value = val.to_f
      else
        raise ParameterException.new("Parameter -#{code} requires a number ('#{val}' given).")
      end
    elsif @values[key].type == Boolean
      if val.is_a?(Boolean)
        @values[key].value = val
      elsif val.to_s.to_sym == :true || val.to_s.to_sym == :false
        @values[key].value = ( val.to_s.to_sym == :true )
      else
        raise ParameterException.new("Parameter -#{code} requires a boolean ('#{val}' given).")
      end
    elsif @values[key].type.is_a? Array
      if @values[key].type.include?(val.to_sym)
        @values[key].value = val.to_sym
      else
        raise ParameterException.new("Invalid value '#{val}' for parameter -#{code}\nChoose one of [#{@values[key].type.map { |e| e.to_s }.join(', ')}].")
      end
    else
      # This should never happen
      raise RuntimeError.new("Parameter -#{code} has unknown type #{@values[key].type}.")
    end

    @hooks[key].each do |b|
      b.call(key, @values[key].value)
    end

    # @copy_dirty = true
  end

  def add(key, val, once = false) # TODO: implement "once" behaviour
    unless @values.key?(key)
      raise ParameterException.new("Parameter #{key} does not exist.")
    end

    unless @values[key].type == String
      raise ParameterException.new("Parameter #{key} does not support extension.")
    end

    @values[key].value += val.to_s # TODO: should we add separating `:`?

    @hooks[key].each do |b|
      b.call(key, @values[key].value)
    end

    # @copy_dirty = true
  end

  def addHook(key, &block)
    # if ( @values.has_key?(key) )
    @hooks[key] = [] unless @hooks.key?(key)

    unless block.arity == 2
      raise ParameterException.new('Parameter hooks need to take two parameters (key, new value).')
    end

    @hooks[key].push(block)
  end

  def keys
    @values.keys
  end

  def reset
    # TODO: clear "once" settings
    # @copy_dirty = false
  end

  # def frozenCopy
  #  if ( @frozen_copy == nil || @copy_dirty )
  #    # TODO create a deep copy
  #    copy = self.clone
  #    copy.values = @values.clone # not deep enough!
  #    copy.freeze
  #    @frozen_copy = copy
  #    @copy_dirty = false
  #  end
  #
  #  return @frozen_copy
  # end

  def user_info
    @values.keys.reject do |key|
      @values[key].code.nil?
    end.sort do |a, b|
      @values[a].code <=> @values[b].code
    end.map do |key|
      { code: @values[key].code, type: @values[key].type, help: @values[key].help }
    end
  end

  def to_s
    @values.keys.map do |key|
      "#{key}\t\t#{self[key]}"
    end.join("\n")
  end

  protected

  attr_accessor :values
end

# TODO: document
class Parameter
  # Pass code = nil for an internal parameter that is not shown to users.
  def initialize(key, code, type, default, help)
    @key = key
    @code = code
    @type = type
    @value = default
    @help = help
  end

  public

  def value=(val)
    unless (@type.is_a?(Array) && val.is_a?(@type[0].class)) || val.is_a?(@type)
      raise ParameterException.new("Value if type #{val.class} is not compatible with parameter #{@key}.")
    end

    @value = val
  end

  attr_reader :key, :code, :type, :value, :help
end

# TODO: document
class ParameterException < RuntimeError
  def initialize(msg)
    super(msg)
  end
end

# For nice type checks on booleans
module Boolean; end
class TrueClass; include Boolean; end
class FalseClass; include Boolean; end
