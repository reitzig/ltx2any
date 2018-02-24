# Copyright 2010-2017, Raphael Reitzig
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

Dependency.new('xelatex', :binary, [:logwriter, 'pdf'], :essential, 'Compilation of PDF logs')

ParameterManager.instance.addHook(:logformat) { |_, newValue|
  if newValue == :pdf
    DependencyManager.list(type: :all, source: [:logwriter, 'pdf'], relevance: :essential).each { |dep|
      unless dep.available?
        Output.instance.warn("#{dep.name} is not available to build PDF logs.", 'Falling back to Markdown log.')
        ParameterManager.instance[:logformat] = :md
        break
      end
    }
  end
}

class PDF < LogWriter
  def self.name
    'PDF'
  end

  def self.description
    'Create a PDF log.'
  end

  def self.to_sym
    :pdf
  end

  # Returns the name of the written file, or raises an exception
  def self.write(log, level = :warning)
    params = ParameterManager.instance
    target_file = "#{params[:log]}.pdf"

    latex_log = LogWriter[:latex].write(log, level)
    # TODO which engine to use?
    xelatex = '"xelatex -file-line-error -interaction=nonstopmode \"#{latex_log}\""'
    IO::popen(eval(xelatex)) { |x| x.readlines }
    IO::popen(eval(xelatex)) { |x| x.readlines }
    # TODO parse log and rewrite a readable version?

    # This is just the default of XeLaTeX
    xelatex_target = latex_log.sub(/\.tex$/, '.pdf')

    if !File.exist?(xelatex_target)
      # This should never happen! Still, let's fail gracefully.
      msg = ['Log failed to compile!']
      if params[:daemon] || !params[:clean]
        msg << "See #{params[:tmpdir]}/#{latex_log}.log for details."
      end
      msg << 'Falling back to Markdown log.'

      Output.instance.error(*msg)
      target_file = LogWriter[:md].write(log, level)
    elsif xelatex_target != target_file
      FileUtils::cp(xelatex_target, target_file)
    end

    target_file
  end
end

LogWriter.add PDF