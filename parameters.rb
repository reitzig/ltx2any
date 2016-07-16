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

[
  Parameter.new(:user_jobname, "j", String, '"#{self[:jobname]}"',
                "Job name, in particular name of the resulting file."),
  Parameter.new(:clean, "c", Boolean, false,
                "If set, temporary files are deleted."),
  Parameter.new(:cleanall, "ca", Boolean, false,
                "If set, temporary files and logs are deleted."),
  Parameter.new(:log, "l", String, '"#{self[:user_jobname]}.log"',
                "(Base-)Name of log file."),
  Parameter.new(:tmpdir, "t", String, '"#{self[:user_jobname]}#{TMPSUFFIX}"',
                "Directory for intermediate results")
].each { |p|
  ParameterManager.instance.addParameter(p)
}

ParameterManager.instance.addHook(:cleanall) { |k,v|
  ParameterManager.instance[:clean] = true if v
}
