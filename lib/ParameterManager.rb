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

  def addParameter(p)
    raise ParameterException.new('Can not add parameters after CLI input has been processed.') if @processed

    raise ParameterException.new("Can not add object of type #{p.class} as parameter.") unless p.is_a?(Parameter)

    raise ParameterException.new("Parameter #{p.key} already exists.") if @values.key?(p.key)

    @values[p.key] = p
    @code2key[p.code] = p.key
    @hooks[p.key] = [] unless @hooks.key?(p.key)
  end

  def processArgs(_args)
    # Check for input file first
    # Try to find an existing file by attaching common endings
    original = ARGV.last
    endings = ['tex', 'ltx', 'latex', '.tex', '.ltx', '.latex']
    jobfile = original
    while !File.exist?(jobfile) || File.directory?(jobfile)
      raise ParameterException.new("No input file fitting #{original} exists.") if endings.empty?

      jobfile = "#{original}#{endings.pop}"
    end
    # TODO: do basic checks as to whether we really have a LaTeX file?

    addParameter(Parameter.new(:jobpath, nil, String, File.dirname(File.expand_path(jobfile)),
                               'Absolute path of source directory'))
    addHook(:tmpdir) do |_key, val|
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
      raise ParameterException.new("Don't know what to do with parameter #{ARGV[i]}.") if p.nil?

      code = p[1]
      key = @code2key[code]

      raise ParameterException.new("Parameter -#{code} does not exist.") unless @values.key?(key)

      if @values[key].type == Boolean
        set(key, :true)
        i += 1
      else
        val = ARGV[i + 1]
        raise ParameterException.new("No value for parameter -#{code}.") unless i + 1 < ARGV.length - 1

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

    raise ParameterException.new('Please provide an input file. Call with --help for details.') if jobfile.nil?

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

  def set(key, val, _once = false) # TODO: implement "once" behaviour
    # TODO allow for proper validation functions?
    # TODO fall back to defaults instead of killing?
    raise ParameterException.new("Parameter #{key} does not exist.") unless @values.key?(key)

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
        @values[key].value = (val.to_s.to_sym == :true)
      else
        raise ParameterException.new("Parameter -#{code} requires a boolean ('#{val}' given).")
      end
    elsif @values[key].type.is_a? Array
      if @values[key].type.include?(val.to_sym)
        @values[key].value = val.to_sym
      else
        raise ParameterException.new("Invalid value '#{val}' for parameter -#{code}\nChoose one of [#{@values[key].type.map do |e|
                                                                                                        e.to_s
                                                                                                      end.join(', ')}].")
      end
    else
      # This should never happen
      raise "Parameter -#{code} has unknown type #{@values[key].type}."
    end

    @hooks[key].each do |b|
      b.call(key, @values[key].value)
    end

    # @copy_dirty = true
  end

  def add(key, val, _once = false) # TODO: implement "once" behaviour
    raise ParameterException.new("Parameter #{key} does not exist.") unless @values.key?(key)

    raise ParameterException.new("Parameter #{key} does not support extension.") unless @values[key].type == String

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
