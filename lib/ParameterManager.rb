# Copyright 2010-2013, Raphael Reitzig
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
  def self.dependencies
    return []
  end
  
# TODO Make it so that keys are (also) "long" codes as fas as users are concerned. Interesting for DaemonPrompt!
  def initialize
    parameters = [
      Parameter.new(:jobname,        "j",        String,                         nil,
                    "Job name, in particular name of result file."), 
      Parameter.new(:clean,          "c",        Boolean,                        false,
                    "If set, all intermediate results are deleted."),
      Parameter.new(:daemon,         "d",        Boolean,                        false,
                    "Re-compiles automatically when files change."),
      Parameter.new(:listeninterval, "di",       Float,                          0.5,
                    "Re-compiles automatically when files change."),
      Parameter.new(:enginepar,      "ep",       String,                         "",
                    "Parameters passed to the engine, separated by spaces."),
      Parameter.new(:log,            "l",        String,                         '"#{self[:jobname]}.log"',
                    "(Base-)Name of log file."),
      Parameter.new(:logformat,      "lf",       [:raw, :md, :pdf],              :md,
                    "Set to 'raw' for raw, 'md' for Markdown or 'pdf' for PDF log."),
      Parameter.new(:loglevel,       "ll",       [:error, :warning, :info],      :warning,
                    "Set to 'error' to see only errors, to 'warning' to see also warnings, or to 'info' for everything."),
      Parameter.new(:runs,           "n",        Integer,                        0,
                    "How often the LaTeX compiler runs. Values smaller than one will cause it to run until the resulting file no longer changes. May not apply to all engines."),
      Parameter.new(:tmpdir,         "t",        String,                         '"#{self[:jobname]}_tmp"',
                    "Directory for intermediate results")
    ]

    @values = {}
    @hooks = {}
    @code2key = {}
    @processed = false

    parameters.each { |p|
      addParameter(p)
    }
    
    #@frozen_copy = nil
    #@copy_dirty = false
    #frozenCopy()
  end

  public
    def addParameter(p)
      if ( !@processed )
        if ( p.is_a?(Parameter) )
          if ( @values.has_key?(p.key) )
            raise ParameterException.new("Parameter #{p.key} already exists.")
          else
            @values[p.key] = p
            @code2key[p.code] = p.key
            @hooks[p.key] = []
          end
        else
          raise ParameterException.new("Can not add object of type #{p.class} as parameter.")
        end
      else
        raise ParameterException.new("Can not add parameters after CLI input has been processed.")
      end
    end

    def processArgs(args)
      # Check for input file first
      # Try to find an existing file by attaching common endings
      original = ARGV.last
      endings = ["tex", "ltx", "latex", ".tex", ".ltx", ".latex"]
      jobfile = original
      while ( !File.exist?(jobfile) || File.directory?(jobfile) )
        if ( endings.length == 0 )
          raise ParameterException.new("No input file fitting #{original} exists.")
        end

        jobfile = "#{original}#{endings.pop}"
      end
      # TODO do basic checks as to whether we really have a LaTeX file?

      addParameter(Parameter.new(:jobpath, "", String, File.dirname(File.expand_path(jobfile)), 
                                 "Absolute path of source directory"))
      addHook(:tmpdir) { |key,val|
        if ( self[:jobpath].start_with?(File.expand_path(val)) )
          raise ParameterException.new("Temporary directory may not contain job directory.")
        end
      }
      addParameter(Parameter.new(:jobfile, "", String, File.basename(jobfile), "Name of the main input file"))
      set(:jobname, /\A(.+?)\.\w+\z/.match(self[:jobfile])[1])

      # Evaluate defaults that need to/can be evaluated
      keys.each { |key|
        val = @values[key].value
        if ( val != nil && val.is_a?(String) && val.length > 0 )
          begin
            @values[key].value = eval(val)
          rescue Exception => e
            # Leave value unchanged
            # puts "From eval on #{key}: #{e.message}"
          end
        end
      }

      # Read in parameters
      # TODO use/build proper CLI and parameter handler?
      i = 0
      while ( i < ARGV.length - 1 )
        p = /\A-(\w+)\z/.match(ARGV[i])
        if p != nil
          code = p[1]
          key = @code2key[code]

          if ( @values.has_key?(key) )
            if ( @values[key].type == Boolean )
              set(key, :true)
              i += 1
            else
              val = ARGV[i+1]
              if ( i + 1 < ARGV.length - 1 )
                set(key, val) # Does all the checking and converting
                i += 2
              else
                raise ParameterException.new("No value for parameter -#{code}.")
              end
            end
          else
            raise ParameterException.new("Parameter -#{code} does not exist.")
          end
        else
          raise ParameterException.new("Don't know what to do with parameter #{ARGV[i]}.")
        end
      end

      if ( jobfile == nil )
        raise ParameterException.new("Please provide an input file. Call with --help for details.")
      end

      @processed = true
    end
    
    def [](key)
      if ( @values.has_key?(key) )
        return @values[key].value
      else
        return nil
      end
    end

    def []=(key,val)
      set(key, val, false)
    end

    def set(key, val, once=false) # TODO implement "once" behaviour
      # TODO allow for proper validation functions?
      # TODO fall back to defaults instead of killing?
      if( !@values.has_key?(key) )
        raise ParameterException.new("Parameter #{key} does not exist.")
      end
      code = @values[key].code

      if ( @values[key].type == String )
        @values[key].value = val
      elsif ( @values[key].type == Integer )
        if ( /\d+/ =~ val )
          @values[key].value = val.to_i
        else
          raise ParameterException.new("Parameter -#{code} requires an integer ('#{val}' given).")
        end
      elsif ( @values[key].type == Float )
        if ( /\d+(\.\d+)?/ =~ val )
          @values[key].value = val.to_f
        else
          raise ParameterException.new("Parameter -#{code} requires a number ('#{val}' given).")
        end
      elsif ( @values[key].type == Boolean )
        val = val.to_s.to_sym
        if ( val == :true || val == :false )
          @values[key].value = ( val == :true )
        else
          raise ParameterException.new("Parameter -#{code} requires a boolean ('#{val}' given).")
        end
      elsif ( @values[key].type.is_a? Array )
        if ( @values[key].type.include?(val.to_sym) )
          @values[key].value = val.to_sym
        else
          raise ParameterException.new("Invalid value '#{val}' for parameter -#{code}; choose one of [#{@values[key].type.map { |e| e.to_s }.join(", ")}].")
        end
      else
        # This should never happen
        raise RuntimeError.new("Parameter -#{code} has unknown type #{@values[key].type}.")
      end

      @hooks[key].each { |b|
        b.call(key, @values[key].value)
      }

      #@copy_dirty = true
    end

    def add(key, val, once=false) # TODO implement "once" behaviour
      if ( @values.has_key?(key) ) 
        if ( @values[key].type == String )
          @values[key].value += val.to_s

          @hooks[key].each { |b|
            b.call(key, @values[key].value)
          }
          
          #@copy_dirty = true
        else
          raise ParameterException.new("Parameter #{key} does not support extension.")
        end
      else
        raise ParameterException.new("Parameter #{key} does not exist.")
      end
    end

    def addHook(key, &block)
      if ( @values.has_key?(key) )
        if ( block.arity == 2 )
          @hooks[key].push(block)
        else
          raise ParameterException.new("Parameter hooks need to take two parameters.")
        end
      else
        raise ParameterException.new("Parameter #{key} does not exist.")
      end
    end

    def keys
      return @values.keys
    end

    def reset
      # TODO clear "once" settings
      # @copy_dirty = false
    end

    #def frozenCopy
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
    #end

  def user_info
    @values.keys.sort { |a,b| @values[a].code <=> @values[b].code }. map { |key|
      { :code => @values[key].code, :type => @values[key].type, :help => @values[key].help }
    }
  end

  def to_s
    @values.keys.map { |key|
      "#{key}\t\t#{self[key]}"
    }.join("\n")
  end

  protected
    attr_reader :values
    attr_writer :values
end

class Parameter
  def initialize(key, code, type, default, help)
    @key = key
    @code = code
    @type = type
    @value = default
    @help = help
  end

  public
    def value=(val)
      if ( ( @type.is_a?(Array) && val.is_a?(@type[0].class) ) || val.is_a?(@type) )
        @value = val
      else
        raise ParameterException.new("Value if type #{val.class} is not compatible with parameter #{@key}.")
      end
    end

  attr_reader :key, :code, :type, :value, :help
end

class ParameterException < Exception
  def initialize(msg)
    super(msg)
  end
end

# For nice type checks on booleans
module Boolean; end
class TrueClass; include Boolean; end
class FalseClass; include Boolean; end
