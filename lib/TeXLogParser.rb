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

# TODO: document
class TeXLogParser

  # Input:
  #  * log -- string array (one entry per line)
  #  * startregexp -- start collecting messages after first match
  #                   Default: matches any line, thus collects from the start
  #  * endregexp   -- stop collecting at first match after collection started
  #                   Default: matches nothing, thus collects to the end
  # Output: Array of Message objects
  def self.parse(log, startregexp = /.*/, endregexp = /(?=a)b/)
    # Contains a stack of currently "open" files.
    # filestack.last is the current one.
    filestack = []

    # Result collection
    messages = []

    # The stack of files the log is currently "in"
    filestack = []

    collecting = false
    linectr = 1 # Declared for the increment at the end of the loop
    current = Finalizer.new
    ongoing = nil
    log.each do |line|
      if !collecting && startregexp =~ line
        collecting = true
        linectr = 1
      end
      if collecting && endregexp =~ line
        messages += [current.get_msg].compact
        break
      end

      # Even when not collecting, we need to keep track of which file
      # we are in.
      if collecting && line.strip == ''
        # Empty line ends messages
        messages += [current.get_msg].compact
      elsif /^l\.(\d+) (.*)$/ =~ line
        # Line starting with a line number ends messages
        unless current.type.nil?
          current.srcline = [Integer($~[1])] if current.srcline.nil?
          current.message += $~[2].strip
          current.logline[1] = linectr
          messages += [current.get_msg].compact
        end
      elsif /^<\*> (.*)$/ =~ line
        # Some messages end with a line of the form '<*> file'
        unless current.type.nil?
          current.srcfile = $~[1].strip
          current.logline[1] = linectr
          messages += [current.get_msg].compact
        end
      elsif /^(\([^()]*\)|[^()])*\)/ =~ line
        # End of messages regarding current file
        messages += [current.get_msg].compact if collecting

        filestack.pop

        # Multiple files may close; cut away matching part and start over.
        line = line.gsub($~.regexp, '')
        redo
      elsif current.type.nil? && # When we have an active message, it has
          # to complete before a new file can open.
          # Probably. (Without, error messages with
          # opening but no closing parenthesis would
          # skrew up file tracking.)
          /^[^()]*(\([^()]*\).*?)*[^()]*\(([^()]*?(\(|$))/ =~ line
        #       {                          }
        #       skip series of matching parens and gutter
        #                                   {        }
        #                                   opening paren and potential filename
        #
        # A new file has started. Match only those that don't close immediately.
        candidate = $~[2]

        while !File.exist?(candidate) && candidate != '' do # TODO can be long; use heuristics?
          candidate = candidate[0,candidate.length - 1]
        end
        if File.exist?(candidate)
          filestack.push(candidate)
        else
          # Lest we break everything by false negatives (due to linebreaks),
          # add a dummy and hope it closes.
          filestack.push('dummy')
        end

        # Multiple files may open; cut away matching part and start over.
        replace = if ['('].include?($~[3]) then $~[3] else
                                                            ''
                  end
        line = line.gsub($~.regexp, replace)
        redo
      elsif collecting # Do all the checks only when collecting
        if /^(\S*?):(\d+): (.*)/ =~ line && ongoing.nil? # such lines appear in fontspec-style messages, see below
          messages += [current.get_msg].compact
          # messages.push(LogMessage.new(:error, $~[1], [Integer($~[2])], [linectr], $~[3].strip))

          current.type = :error
          current.srcfile = $~[1]
          current.srcline = [Integer($~[2])]
          current.logline = [linectr]
          current.message = $~[3].strip + "\n"
          current.slicer = nil
          current.format = :fixed
        elsif /(Package|Class)\s+([\w]+)\s+(Warning|Error|Info)/ =~ line
          # Message from some package or class, may be multi-line
          messages += [current.get_msg].compact

          current.type = if $~[3] == 'Warning'
                         then :warning
                         elsif $~[3] == 'Info'
                         then :info
                         else :error
                         end
          current.srcfile = filestack.last
          current.srcline = nil
          current.logline = [linectr]
          current.message = line.strip
          current.slicer = /^\(#{$~[2]}\)\s*/
        elsif /\w+?TeX\s+(Warning|Error|Info)/ =~ line
          # Some message from the engine, may be multi-line
          messages += [current.get_msg].compact

          current.type = if $~[1] == 'Warning'
                         then :warning
                         elsif $~[1] == 'Info'
                         then :info
                         else :error
                         end
          current.srcfile = filestack.last
          current.srcline = nil
          current.logline = [linectr]
          current.message = line.strip
          current.slicer = /^\s*/
        elsif /^(LaTeX Font Warning: .*?)(?: #{space_sep('on input line')} (\d+).)?$/ =~ line
          # Some issue with fonts
          messages += [current.get_msg].compact

          current.type = :warning
          current.srcfile = filestack.last
          current.srcline = $~[2] ? [Integer($~[2])] : nil
          current.logline = [linectr]
          current.message = $~[1].strip
          current.slicer  = /^\(Font\)\s*/
        elsif /^((Under|Over)full .*?) #{space_sep('at lines')} (\d+)--(\d+)?/ =~ line
          # Engine complains about under-/overfilled boxes
          messages += [current.get_msg].compact

          fromLine = Integer($~[3])
          toLine = Integer($~[4])
          srcLine = [fromLine]
          if toLine >= fromLine
            srcLine[1] = toLine
          else
            # This seems to happen for included files. The first number is the
            # line in the including file, the second in the included one.
            # TODO What for chains?
            srcLine = [toLine]
          end

          messages.push(LogMessage.new(:warning, filestack.last, srcLine, [linectr], $~[1].strip))
        elsif /^((Under|Over)full .*?)[\d\[\]]*$/ =~ line
          messages += [current.get_msg].compact
          messages.push(LogMessage.new(:warning, filestack.last, nil, [linectr], $~[1].strip))
        elsif /^Runaway .*?\?$/ =~ line
          messages += [current.get_msg].compact
          current.type = :error
          current.srcfile = filestack.last
          current.srcline = nil
          current.logline = [linectr]
          current.message = line.strip + "\n"
          current.format = :fixed
        elsif /^!!+/ =~ line
          # Messages in the style of fontspec
          messages += [current.get_msg].compact

          ongoing = :fontspec
          current.type = :error
          current.srcfile = filestack.last # may be overwritten later
          current.srcline = nil
          current.logline = [linectr]
          current.message = ''
          current.format = :fixed
        elsif ongoing == :fontspec # Precedence over other lines starting with !, see below
          if /^!\.+/ =~ line.strip
            # Message is done
            ongoing = nil
            messages += [current.get_msg].compact
            current = Finalizer.new
          elsif /^(?:\.\/)?(\S+?):(\d+): (.*)/ =~ line
            current.srcfile = $~[1]
            current.srcline = [Integer($~[2])]
            current.message += $~[3].strip + "\n"
          elsif /^! For immediate help.*/ =~ line
            # Drop useless note
          elsif /^!(.*)/ =~ line
            # A new line
            current.message += $~[1].strip + "\n" unless $~[1].strip.empty?
          end
        elsif /^! (.*?)(after line (\d+).)?$/ =~ line
          messages += [current.get_msg].compact
          current.type = :error
          current.srcfile = filestack.last
          current.srcline = $~[3] ? [Integer($~[3])] : nil
          current.logline = [linectr]
          current.message = $~[1] + ($~[2] ? $~[2] : '')
        elsif !current.type.nil?
          line = line.gsub(current.slicer, '') unless current.slicer.nil?
          line = ' ' + line.strip! if current.format != :fixed
          current.message += line
          current.logline[1] = linectr
        end
      end

      linectr += 1
    end

    return messages
  end

  private

  # TeX logs may have spaces in weird places. If we don't want our regexp
  # matching to stumble over that, longer strings have to be matched
  # allowing for whitespace everywhere.
  # Use the result of this method for this purpose.
  def self.space_sep(s)
    s.chars.join('\s*')
  end

  # Some messages may run over multiple lines. Use an instance
  # of this class to collect it completely.
  class Finalizer
    def initialize
      reset
    end

    def reset
      @type = nil
      @srcfile = nil
      @srcline = nil
      @logline = nil
      @message = nil
      @format = :none

      @slicer = nil
    end

    public

    attr_accessor :type, :srcfile, :srcline, :logline, :message, :format, :slicer

    #  (initially: @currentmessage = [nil, nil, nil, nil, nil, nil, :none] )
    def get_msg()
      if !@type.nil?
        if @srcline.nil? && @message =~ /(.+?) #{TeXLogParser::space_sep('on input line')} (\d+)\.?$/
          # The first line did not contain the line of warning, but
          # the last did!
          @message = $~[1].strip
          @srcline = [Integer($~[2])]
        end
        res = LogMessage.new(@type, @srcfile, @srcline, @logline, @message, @format)
        reset
        res
      else
        reset
        nil
      end
    end
  end
end
