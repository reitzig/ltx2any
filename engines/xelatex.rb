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

Dependency.new('xelatex', :binary, [:engine, 'xelatex'], :essential)

# TODO: document
class XeLaTeX < Engine
  def initialize
    super
    @binary = 'xelatex'
    @extension = 'pdf'
    @description = 'Uses XeLaTeX to create a PDF'

    @target_file = "#{ParameterManager.instance[:jobname]}.#{extension}"
    @old_hash = hash_result
  end

  def do?
    !File.exist?(@target_file) || hash_result != @old_hash
  end

  def hash_result
    HashManager.hash_file(@target_file, drop_from: /CIDFontType0C|Type1C/)
  end

  def exec
    @old_hash = hash_result

    # Command for the main LaTeX compilation work
    params = ParameterManager.instance
    xelatex = "xelatex -file-line-error -interaction=nonstopmode #{params[:enginepar]} '#{params[:jobfile]}'"

    f = IO.popen(xelatex)
    log = f.readlines.map! { |s| Log.fix(s) }

    parsed_log = TexLogParser.new(log).parse
    { success: File.exist?(@target_file), messages: parsed_log, log: log.join.strip! }
  end
end

Engine.add XeLaTeX
