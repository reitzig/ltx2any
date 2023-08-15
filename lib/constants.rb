# frozen_string_literal: true

# Copyright 2010-2018, Raphael Reitzig
#
# This file is part of chew.
#
# chew is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# chew is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with chew. If not, see <http://www.gnu.org/licenses/>.

module Chew
  NAME       = 'chew'
  VERSION    = '1.0.0-beta'
  YEAR       = '2019'
  AUTHORS    = ['Raphael Reitzig'].freeze
  TMPSUFFIX  = '_tmp'
  HASHFILE   = '.hashes' # relative to tmp directory

  WORKDIR = Dir.pwd.freeze
  BASEDIR = File.expand_path(__dir__).freeze
  LIBDIR  = 'util'
  EXTDIR  = 'extensions'
  ENGDIR  = 'engines'
  LOGWDIR = 'logwriters'
end