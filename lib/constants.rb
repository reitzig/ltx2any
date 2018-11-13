# frozen_string_literal: true

# Copyright 2016, Raphael Reitzig
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

# TODO: move to a properties file? module?

NAME       = 'chew'
VERSION    = '1.0.0-beta'
YEAR       = '2018'
AUTHOR     = 'Raphael Reitzig'
TMPSUFFIX  = '_tmp'
HASHFILE   = '.hashes' # relative to tmp directory

WORKDIR = Dir.pwd.freeze
BASEDIR = File.expand_path(__dir__).freeze
LIBDIR  = 'util'
EXTDIR  = 'extensions'
ENGDIR  = 'engines'
LOGWDIR = 'logwriters'
