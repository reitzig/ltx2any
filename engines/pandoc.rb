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

class Pandoc < Engine 

  def initialize
    super
    
    @name = "pandoc"
    @description = "Translates into many formats (see 'pandoc --help')"
    @codes = { "f" => ["string", "targetformat", "Selects one of the target formats of pandoc."]}
    @params = { "targetformat" => nil } # TODO how to pass other parameters to pandoc?
    
    @format2ending = {
      "native" => "txt",
      "json" => "js", 
      "docx" => "docx", 
      "odt" => "odt", 
      "epub" => "epub", 
      "epub3" => "epub", 
      "fb2" => "fb2", 
      "html" => "html", 
      "html5" => "html", 
      "s5" => "html",
      "slidy" => "html", 
      "slideous" => "html", 
      "dzslides" => "html", 
      "docbook" => "dbk", 
      "opendocument" => "odt", 
      "latex" => "tex", 
      "beamer" => "tex",
      "context" => "tex", 
      "texinfo" => "texi", 
      "man" => "man", 
      "markdown" => "md", 
      "markdown_strict" => "md",
      "markdown_phpextra" => "md", 
      "markdown_github" => "md", 
      "markdown_mmd" => "md", 
      "plain" => "txt", 
      "rst" => "rst",
      "mediawiki" => "wiki", 
      "textile" => "txt", 
      "rtf" => "rtf", 
      "org" => "org", 
      "asciidoc" => "txt"
    }
  end

  def extension 
    @format2ending[$params["targetformat"]]
  end

  def do?
    false # Pandoc does never have to be run repeatedly
  end

  def exec()
    if ( $params["targetformat"] == nil ) # TODO implement message objects
      return [false, ["not yet implemented"], "Specify a target format by adding '-format [format]' as parameter."]
    elsif ( @format2ending[$params["targetformat"]] == nil )
      return [false, ["not yet implemented"], "Pandoc does not know target format #{$params["targetformat"]}"]
    end
    
    # Command for the main LaTeX compilation work.
    # Uses the following variables:
    # * jobfile -- name of the main LaTeX file (with file ending)
    # * tmpdir  -- the output directory
    pandoc = '"pandoc -f latex -t #{$params["targetformat"]} -o \"#{$jobname}.#{extension}\" #{$jobfile} 2>&1"'

    f = IO::popen(eval(pandoc))
    log = f.readlines
  
    # TODO implement log parser
    return [File.exist?("#{$jobname}.#{extension}"), ["not yet implemented"], log.join("")]
  end
end

$tgt = Pandoc.new
