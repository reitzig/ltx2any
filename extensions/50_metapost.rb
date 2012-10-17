# Copyright 2010-2012, Raphael Reitzig
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

$ext = Extension.new(
  "metapost",

  "Parses metapost files (Dummy)",

  {},

  {},

  lambda {
    false # TODO implement
  },

  lambda {
    # Command to parse metapost files after first LaTeX run.
    # Make sure its parameterisation fits the used LaTeX compiler.
    # Uses the following variables:
    # * mpfile  -- the name of the metapost file to be parsed
    metapost = '"mpost -tex=pdflatex -interaction=nonstopmode #{mpfile}"'
    progress(3)

   # TODO implement
   return [false, "Dummy"]
  })
