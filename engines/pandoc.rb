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

DependencyManager.add("pandoc", :binary, :recommended)
ParameterManager.instance.addHook(:engine) { |key, val|
  if ( val == :pandoc )
    DependencyManager.make_essential("pandoc", binary)
    DependencyManager.add("cat", :binary, :essential)
    DependencyManager.add("grep", :binary, :essential)
  end
}
ParameterManager.instance.addParameter(
  Parameter.new(:targetformat, "f", String, nil, "Selects one of the target formats of pandoc.")
  # TODO add only if pandoc is used? where to show it then?
)

class Pandoc < Engine 
  def initialize
    super
    
    @binary = "pandoc"
    @description = "Translates into many formats (see 'pandoc --help')"
    
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
    @format2ending[params[:targetformat]]
  end

  def do?
    false # Pandoc does never have to be run repeatedly
  end

  def exec()
    params = ParameterManager.instance
  
    if ( params[:targetformat] == nil )
      msg = "Specify a target format by adding '-f <format>' as parameter."
      return [false, [LogMessage.new(:error, nil, nil, nil, msg)], msg]
    elsif ( @format2ending[params[:targetformat]] == nil )
      msg = "Pandoc does not know target format #{params[:targetformat]}"
      return [false, [LogMessage.new(:error, nil, nil, nil, msg)], msg]
    end
    # TODO warn if executed multiple times?
    
    # Command for the main LaTeX compilation work.
    # Uses the following variables:
    # * jobfile -- name of the main LaTeX file (with file ending)
    # * tmpdir  -- the output directory
    pandoc = '"pandoc -s -f latex -t #{params[:targetformat]} -o \"#{params[:jobname]}.#{extension}\" #{params[:jobfile]} 2>&1"'

    f = IO::popen(eval(pandoc))
    log = f.readlines + [""] # One empty line to finalize the last message
  
    msgs = [LogMessage.new(:warning, nil, nil, nil, 
              "Beware, the LaTeX parser of pandoc does not report most non-critical errors! " + 
              "Therefore, your output may still be broken even if you see no messages here.")]
              
    current = []
    linectr = 1
    errors = false
    log.each { |line|
      if ( /Error:/ =~ line )
        current = [:error, linectr, ""]
        errors = true
      elsif ( /Warning:/ =~ line ) # Does that even exist?
        current = [:warning, linectr, ""]
      elsif ( current != [] && line.strip == "" )
        msgs.push(LogMessage.new(current[0], nil, nil, [current[1], linectr - 1], current[2], :fixed))
        current = []
      elsif ( current != [] )
        current[2] += line
      end
      
      linectr += 1
    }
    
    return [!errors, msgs, log.join("").strip!]
  end
end

Engine.add Pandoc
