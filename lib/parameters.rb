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

# TODO: migrate to util/option_parser.rb

[
  Parameter.new(:clean, 'c', Boolean, false,
                'Delete temporary files'),
  Parameter.new(:cleanall, 'ca', Boolean, false,
                'Delete temporary files and logs'),
  Parameter.new(:tmpdir, 't', String, '"#{self[:user_jobname]}#{TMPSUFFIX}"',
                'Directory for temporary files'),
  Parameter.new(:ignore, 'i', String, '',
                'Files to ignore, separated by colons'),
].each { |p|
  ParameterManager.instance.addParameter(p)
}

ParameterManager.instance.addHook(:cleanall) { |_, v|
  ParameterManager.instance[:clean] = true if v
}
