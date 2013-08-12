# Copyright 2010-2013, Raphael Reitzig
# <code@verrech.net>
# Version 1.0 beta
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

require 'fileutils'
require 'rubygems'
require 'digest'
require 'yaml'
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each { |f| require f }

# Some frontend strings
name      = "ltx2any"
shortcode = "[#{name}]"
running   = "running"
done      = "Done"
error     = "Error"
tmpsuffix = "_tmp"
ignorefile = ".#{name}ignore_"

begin
  puts "#{shortcode} Initialising ..." # TODO abstract away printing

  # Parameter codes, type, names and descriptions
  codes = {
    "t" => ["string", "tmpdir",     "Directory for intermediate results"],
    "lf" => ["string", "logformat", "Set to 'raw' for raw, 'md' for Markdown or 'pdf' for PDF log."],
    "ll" => ["string", "loglevel",  "Set to 'error' to see only errors, to 'warning' to\n" +
                                "\t\tsee also warnings, or to 'info' for everything."],
    "n" => ["int", "ltxruns",       "How often the LaTeX compiler runs. Values\n" +
                                "\t\tsmaller than 1 will cause it to run until the\n" +
                                "\t\tresulting file no longer changes."],
    "c" => [nil, "clean",           "If set, all intermediate results are deleted."],
    "e" => ["string", "engine",     "The output engine. Call with --engines for a list."],
    "d" => [nil, "daemon",          "Reruns ltx2any automatically when files change."]
  }

  # Parameter default values
  $params = {
    "tmpdir"    => '"#{$jobname}#{tmpsuffix}"',
    "log"       => '"#{$jobname}.log"',
    "logformat" => "md",
    "loglevel"  => "warning",
    "hashes"    => ".hashes",
    "ltxruns"   => 0,
    "clean"     => false,
    "engine"    => "pdflatex",
    "daemon"    => false
  } # TODO make parameter names symbols

  dependencies =  [["which", :binary, :essential],
                   ["listen", :gem, :recommended, "for daemon mode"]]
                                 
  # Load all extensions
  extensions = []
  $ext = nil
  Dir[File.dirname(__FILE__) + '/extensions/*.rb'].sort.each { |f|
    if ( !(/^\d\d/ !~ File.basename(f)) )
      load(f)

      if ( $ext != nil && $ext.kind_of?(Extension) )
        extensions.push($ext)
      end

      $ext = nil
    end
  }

  # Read additional parameters and their defaults from extensions but always
  # keep present values.
  extensions.each { |e|
    # Add extension information
    if ( e.codes != nil )
      codes = e.codes.merge(codes)
    end
    if ( e.params != nil )
      $params = e.params.merge($params)
    end
  }

  # Load all engines
  engines = []
  $tgt = nil
  Dir[File.dirname(__FILE__) + '/engines/*.rb'].sort.each { |f|
    load(f)

    if ( $tgt != nil && $tgt.kind_of?(Engine) )
      engines.push($tgt)
    end

    $tgt = nil
  }
  
  # Read additional parameters and their defaults from engines but always
  # keep present values.
  engines.each { |e|
    # Add extension information
    if ( e.codes != nil )
      codes = e.codes.merge(codes)
    end
    if ( e.params != nil )
      $params = e.params.merge($params)
    end
  }

  # process command line parameters
  if ( ARGV.length == 0 || !(/--help|-help|--h|-h|help|\?/ !~ ARGV[0]) )
    puts "\nUsage: "
    puts "  #{name} [options] inputfile\tNormal execution (see below)"
    puts "  #{name} --extensions\t\tList of extensions"
    puts "  #{name} --engines\t\tList of target engines"
    puts "  #{name} --help\t\tThis message"

    puts "\nOptions:"
    codes.keys.sort.each { |key|
      puts "  -#{key}\t#{if ( codes[key][0] != nil ) then codes[key][0] end}\t#{codes[key][2]}"
    }
    
    # TODO output unsatisfied dependencies

    Process.exit
  elsif ( ARGV[0] == "--extensions" ) # TODO check dependencies
    puts "Installed extensions in order of execution:"
    extensions.each { |e|
      puts "  #{e.name}\t#{e.description}"
    }
    Process.exit
  elsif ( ARGV[0] == "--engines" ) # TODO check dependencies in better way
    puts "Installed engines:"
    engines.each { |t|
      if ( `which #{t.name}` != "" )
        print "  #{t.name}\t#{t.description}"
        if ( t.name == $params["engine"] )
          print " (default)"
        end
        puts ""
      end
    }
    Process.exit
  else
    # Read in parameters
    i = 0
    while ( i < ARGV.length )
      p = /\A-(\w+)\z/.match(ARGV[i])
      if p != nil
        p = p[1]

        if ( !codes.key?(p) )
          puts "#{shortcode} No such parameter: -" + p
          i += 1
        else
          if ( codes[p][0] == "int" )
            $params[codes[p][1]] = ARGV[i+1].to_i
            i += 2
          elsif ( codes[p][0] == "string" )
            $params[codes[p][1]] = ARGV[i+1]
            i += 2
          else
            $params[codes[p][1]] = true
            i += 1
          end
        end
      else
        $jobfile = ARGV[i]
        break
      end
    end

    if ( $jobfile == nil )
      puts "#{shortcode} Please provide input file. Call with --help for details."
      Process.exit
    end

    # Try to find an existing file by attaching common endings
    original = $jobfile
    endings = ["tex", "ltx", "latex"]
    while ( !File.exist?($jobfile) )
      if ( endings.length == 0 )
        puts "#{shortcode} No file fitting #{original} exists."
        Process.exit
      end

      $jobfile = original + "." + endings.pop
    end

    # Use filename without ending as jobname
    $jobname = /\A(.+?)\.\w+\z/.match(File.basename($jobfile))[1]

    #Switch working directory to jobfile residence and get rid of directory prefix
    Dir.chdir(File.dirname($jobfile))
    $jobfile = File.basename($jobfile)

    # If the tmpdir string can be evaluated, do so
    if ( /\A".+?"\z/ =~ $params["tmpdir"] )
      $params["tmpdir"] = eval($params["tmpdir"])
    end
    # If the log string can be evaluated, do so
    if ( /\A".+?"\z/ =~ $params["log"] )
      $params["log"] = eval($params["log"])
    end
    
    # TODO move these checks up; parameter reader should allow 
    #      to specify a fixed set of possible values.
    $params["logformat"] = $params["logformat"].to_sym
    if ( ![:raw, :md, :pdf].include?($params["logformat"]) )
      puts "#{shortcode} Log format \'#{$params["logformat"]}\' not valid, falling back to \'md\''"
      $params["logformat"] = :md 
    end
    $params["loglevel"] = $params["loglevel"].to_sym
    if ( ![:error, :warning, :info].include?($params["loglevel"]) )
      puts "#{shortcode} Log level \'#{$params["loglevel"]}\' not valid, falling back to \'warning\''"
      $params["loglevel"] = :warning 
    end
  end

  # Kill command line parameters in order to discourage abuse by extensions
  ARGV.clear

  # Find used engine
  engine = nil
  engines.each { |t|
    if ( t.name == $params["engine"] )
      engine = t
      break
    end
  }
  if ( engine == nil ) 
    puts "#{shortcode} No such engine: #{$params["engine"]}. Use --engines to list availabe engines."
    Process.exit
  elsif ( `which #{engine}` == "" ) # TODO make obsolete by proper dependency check
    puts "#{shortcode} Engine not available. Please install #{$params["engine"]} and make sure it is in the executable path."
    Process.exit
  end

  # Make sure that target directory is available
  if ( !File.exist?($params["tmpdir"]) )
    Dir.mkdir($params["tmpdir"])
  elsif ( !File.directory?($params["tmpdir"]) )
    puts "#{shortcode} File #{$params["tmpdir"]} exists but is no directory"
    Process.exit
  end

  # Hash function that can be used by engines and extensions
  def filehash(f)
    Digest::MD5.file(f).to_s
  end

  def progress(steps=1) # TODO improve
    print "." * steps
    STDOUT.flush
  end

  $ignoredfiles = ["#{ignorefile}#{$jobname}",
                   "#{$params['tmpdir']}", 
                   "#{$jobname}.#{engine.extension}",
                   "#{$params["log"]}",
                   "#{$jobname}.err",
                   ".listen_test"] # That is some artifact of listen -.-
  # Write ignore list for other processes
  File.open("#{ignorefile}#{$jobname}", "w") { |file| 
    file.write($ignoredfiles.join("\n"))
  }
  
  # Function that reads an ignorefile and extracts filenames
  def ignoremore(ignf)
    tobeignored = []
    if ( File.exist?(ignf) )
      IO.foreach(ignf) { |line|
        tobeignored.push(line.strip)
      }
      $ignoredfiles |= tobeignored   
    end
    return tobeignored
  end
  
  # Collect all existing ignore files
  Dir.entries(".") \
     .select { |f| /(\.\/)?#{Regexp.escape(ignorefile)}[^\/]+/ =~ f } \
     .each { |f|
    ignoremore(f)
  }
  
  
  # Load listen gem and deal with errors
  # TODO move gem-loading/checking code somewhere central so
  #      extensions and engines may use it?
  if ( $params['daemon'] )
    begin
      gem "listen", ">=1.2.0"
      require 'listen'
    rescue Gem::LoadError
      $params['daemon'] = false
      print "#{shortcode} Daemon mode requires gem 'listen'"
      
      begin
        gem "listen"
        puts " 1.2.0 or higher."
      rescue Gem::LoadError
        puts "."
      end
      
      puts (" " * shortcode.length) + 
           " Please install the latest version with 'gem install listen'."
    end
  end
  
  # Setup daemon mode
  if ( $params['daemon'] )
    # Main listener: this one checks job files for changes and prompts recompilation.
    #                (indirectly: The Loop below checks $changetime.)
    $jobfilecallback = Proc.new do |modified, added, removed|
      $changetime = Time.now
    end
    
    $jobfilelistener = Listen.to('.') \
                       .latency(0.5) \
                       .change(&$jobfilecallback) \
                       .ignore(/(\.\/)?#{Regexp.escape(ignorefile)}[^\/]+/) \
                       .ignore(/\A(\.\/)?(#{$ignoredfiles.map { |s| Regexp.escape(s) }.join("|")})/)

    # Secondary listener: this one checks for (new) ignore files, i.e. other
    #                     jobs in the same directory. It then updates the main
    #                     listener so that it does not react to changes in files
    #                     generated by the other process.   
    $ignfilecallback = Proc.new do |modified, added, removed|
      $jobfilelistener.pause
      
      added.each { |ignf|
        files = ignoremore(ignf)
        $jobfilelistener.ignore(/\A(\.\/)?(#{files.map { |s| Regexp.escape(s) }.join("|")})/)
      }

      # TODO If another daemon terminates we keep its ignorefiles. Potential leak!
      #      If this turns out to be a problem, update list & listener (from scratch)
      
      $jobfilelistener.unpause
    end
    
    $ignfilelistener = Listen.to('.') \
                      .filter(/\A(\.\/)?#{Regexp.escape(ignorefile)}[^\/]+/) \
                      .latency(0.1) \
                      .change(&$ignfilecallback)

    $ignfilelistener.start
    $changetime = Time.now
    $jobfilelistener.start
  end

  begin # demon loop
    begin # inner block that can be cancelled by user
      # Reset
      engine.heap = []
      log = Log.new($jobname) # TODO check dependencies
      log.level = $params['loglevel']
      start_time = Time.now

      # Copy all files to tmp directory (some LaTeX packages fail to work with output dir)
      exceptions = $ignoredfiles + $ignoredfiles.map { |s| "./#{s}" } + [".", ".."]

      Dir.entries(".").delete_if { |f| exceptions.include?(f) }.each { |f|
        # Avoid trouble with symlink loops
        if ( File.symlink?(f) )
          if ( !File.exists?("#{$params["tmpdir"]}/#{f}") )
            File.symlink("../#{f}", "#{$params["tmpdir"]}/#{f}")
          end
        else
          FileUtils::rm_rf("#{$params["tmpdir"]}/#{f}")
          FileUtils::cp_r(f,"./#{$params["tmpdir"]}/")
        end
      }

      # Move into temporary directory
      Dir.chdir($params["tmpdir"])

      # Delete former results in order not to pretend success
      if ( File.exist?("#{$jobname}.#{engine.extension}") )
        FileUtils::rm("#{$jobname}.#{engine.extension}")
      end

      # First engine run
      print "#{shortcode} #{engine.name}(1) #{running} ..."
      STDOUT.flush
      r = engine.exec
      puts " #{if r[0] then done else error end}"
      STDOUT.flush

      if ( engine.do? && File.exist?("#{$jobname}.#{engine.extension}") )
        # The first run produced some output so the input is hopefully
        # not completely broken -- continue with the work!
        # (That is, if the engine says it wants to run again.)
      
        # Save the first log if it is the last one (should be before the extensions)
        if ( $params["ltxruns"] ==  1 )
          log.add_messages(engine.name, :engine, r[1], r[2])
        end

        # Read hashes
        $hashes = {}
        hashfile = "#{$params["hashes"]}"
        if ( File.exist?(hashfile) )
          File.open(hashfile, "r") { |f|
            while ( l = f.gets )
              l = l.strip.split(",")
              $hashes[l[0]] = l[1]
            end
          }
        end
        
        # Run all extensions in order
        extensions.each { |e| 
          if ( e.do? ) # TODO check dependencies
            print "#{shortcode} #{e.name} #{running} "
            STDOUT.flush
            r = e.exec()
            puts " #{if r[0] then done else error end}"
            STDOUT.flush
            log.add_messages(e.name, :extension, r[1], r[2])
          end
        }

        # Run engine as often as specified/necessary
        run = 2
        while (  ($params["ltxruns"] > 0 && run <= $params["ltxruns"]) ||
                 ($params["ltxruns"] <= 0 && engine.do?) )
          print "#{shortcode} #{engine.name}(#{run}) #{running} ..."
          STDOUT.flush
          r = engine.exec
          puts " #{if r[0] then done else error end}"
          STDOUT.flush
          run += 1
        end

        # Save the last log if we did not save it already
        if ( $params["ltxruns"] !=  1 )
          log.add_messages(engine.name, :engine, r[1], r[2])
        end
      else
        # First run did not yield a result so there has been a fatal error.
        # Don't bother with extensions or more runs, just stop and
        # report failure.
        log.add_messages(engine.name, :engine, r[1], r[2])
      end

      # Write new hashes
      File.open($params["hashes"], "w") { |file|
        Dir.entries(".").sort.each { |f|
          if ( File::file?(f) )
            file.write(f + "," + filehash(f) + "\n")
          end
        }
      }
      
      errorS = if ( log.count(:error) != 1 ) then "s" else "" end
      warningS = if ( log.count(:warning) != 1 ) then "s" else "" end
      puts "#{shortcode} There were #{log.count(:error)} error#{errorS} " + 
                        "and #{log.count(:warning)} warning#{warningS}."
      
      # Pick up output if present
      if ( File.exist?("#{$jobname}.#{engine.extension}") )
        FileUtils::cp("#{$jobname}.#{engine.extension}","../")
        puts "#{shortcode} Output generated at #{$jobname}.#{engine.extension}"
      else
        puts "#{shortcode} No output generated due to fatal errors."
      end
            
      # Write log
      if ( !log.empty? )
        print "#{shortcode} Assembling log files ... "
        
        # Manage messages from extensions
        extensions.each { |ext|
          if (   !log.has_messages?(ext.name) \
              && File.exist?(".#{name}_extensionmsg_#{ext.name}") )
            # Extension did not run but has run before; load messages from then!
            old = File.open(".#{name}_extensionmsg_#{ext.name}", "r") { |f|
              f.readlines.join
            }
            old = YAML.load(old)
            log.add_messages(ext.name, old[0], old[1], old[2])
          elsif ( log.has_messages?(ext.name) )
            # Write new messages
            File.open(".#{name}_extensionmsg_#{ext.name}", "w") { |f|
              f.write(YAML.dump(log.messages(ext.name)))
            }
          end
        }
        
        target = $params["log"]
        STDOUT.flush
        log.to_s("#{$params["log"]}.raw")
        
        if ( $params['logformat'] == :pdf )
          begin
            log.to_pdf("#{$params["log"]}.pdf")
            
            # Sucks, but OS might not offer correct apps otherwise
            if ( !$params["log"].end_with?(".pdf") )
              target += ".pdf"
            end
          rescue RuntimeError => e
            puts "#{shortcode} Failed to build PDF log:\n" +
                 (" " * shortcode.length) + " " + e.message
                 
            # Fall back to Markdown log
            $params["logformat"] = :md
          end
        end
        if ( $params['logformat'] == :md )
          log.to_md("#{$params["log"]}.md")
          
          # Sucks, but viewers can not choose proper highlighting otherwise
          if ( !$params["log"].end_with?(".md") )
              target += ".md"
            end
        end
                
        FileUtils::cp("#{$params["log"]}.#{$params["logformat"].to_s}", "../#{target}")
        puts "done"
        puts "#{shortcode} Log file generated at #{target}"
        STDOUT.flush
        
        runtime = Time.now - start_time
        # Don't show runtimes of less than 5s (arbitrary)
        if ( runtime / 60 >= 1 || runtime % 60 >= 5 )
          puts "#{shortcode} Took #{sprintf("%d min ", runtime / 60)} #{sprintf("%d sec", runtime % 60)}"
        end
      end
    rescue Interrupt # User cancelled current run
      puts "\n#{shortcode} Cancelled"
    ensure 
      # Return from temporary directory
      Dir.chdir("..")
    end

    if ( $params['daemon'] )
      # Wait until sources changes
      puts "#{shortcode} Waiting for changes... (^c to terminate)"
      while ( $changetime <= start_time || Time.now - $changetime < 2 )
        sleep(0.5)
      end
    end
  end while ( $params['daemon'] )
rescue Interrupt
  puts "\n#{shortcode} Shutdown"
rescue Exception => e
  if ( $jobname != nil )
    puts "\n#{shortcode} ERROR: #{e.message} (see #{$jobname}.err for details)"
    File.open("#{$jobname}.err", "w") { |file| 
      file.write("#{e.message}\n\n#{e.backtrace.join("\n")}") 
    }
  else
    # This is reached due to programming errors or if ltx2any quits early,
    # i.e. if no feasible input file has been specified.
    # Neither case warrants action.
  end
  # Exit immediately. Don't clean up, logs may be necessary for debugging.
  Kernel.exit!(FALSE) 
end

# Stop file listeners
if ( $params['daemon'] )
  $jobfilelistener.stop
  $ignfilelistener.stop
end

# Remove temps if so desired.
if ( $params["clean"] )
  FileUtils::rm_rf($params["tmpdir"])
end
FileUtils::rm_rf("#{ignorefile}#{$jobname}")

