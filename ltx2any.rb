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

require 'io/console'
require 'fileutils'
require 'rubygems'
require 'digest'
require 'yaml'
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each { |f| require f }

# Some frontend strings
# TODO move somewhere nice
name      = "ltx2any"
shortcode = "[#{name}]"
running   = "running"
done      = "Done"
error     = "Error"
cancelled = "Cancelled"
tmpsuffix = "_tmp"
ignorefile = ".#{name}ignore_"
hashes    = ".hashes"

params = ParameterManager.new # For visibility in rescue clause
begin
  puts "#{shortcode} Initialising ..." # TODO abstract away printing

  # params = ParameterManager.new

  dependencies =  [["which", :binary, :essential],
                   ["listen", :gem, :recommended, "for daemon mode"]]
                                 
  # Load all extensions
  # TODO exchange for registering process once this code is in some class
  extensions = []
  $extension = nil
  Dir[File.dirname(__FILE__) + '/extensions/*.rb'].sort.each { |f|
    if ( !(/^\d\d/ !~ File.basename(f)) )
      load(f)

      if ( $extension != nil && $extension.superclass == Extension )
        extensions.push($extension.new(params))
      end

      $extension = nil
    end
  }

  # Load all engines
  # TODO exchange for registering process once this code is in some class
  engines = []
  $engine = nil
  Dir[File.dirname(__FILE__) + '/engines/*.rb'].sort.each { |f|
    load(f)

    if ( $engine != nil && $engine.superclass == Engine )
      engines.push($engine.new(params))
    end

    $engine = nil
  }

  params.addParameter(Parameter.new(:engine, "e", engines.map { |e| e.name.to_sym }, :pdflatex,
                                    "The output engine. Call with --engines for a list."))

  # Read additional parameters from extensions
  extensions.each { |e|
    e.parameters.each { |p|
      params.addParameter(p)
    }
  }
  
  # Read additional parameters from engines
  engines.each { |e|
    e.parameters.each { |p|
      params.addParameter(p)
    }
  }

  # TODO collect all dependencies (from above, extensions, engines, lib/*)

  # TODO Move code to the appropriate places, prettify
  # Check for help/usage commands
  if ( ARGV.length == 0 || /--help|--h/ =~ ARGV[0] )
    puts "\nUsage: "
    puts "  #{name} [options] inputfile\tNormal execution (see below)"
    puts "  #{name} --extensions\t\tList of extensions"
    puts "  #{name} --engines\t\tList of target engines"
    puts "  #{name} --help\t\tThis message"

    puts "\nOptions:"
    #params.keys.sort.each { |key|
    #  puts "  -#{key}\t#{if ( params[key][0] != nil ) then codes[key][0] end}\t#{params[key]}"
    #}
    params.user_info.each { |a|
      puts "  -#{a[:code]}\t#{a[:help]}"
    }
    
    # TODO output unsatisfied dependencies

    Process.exit
  elsif ( ARGV[0] == "--extensions" ) # TODO check dependencies
    puts "Installed extensions in execution order:"
    extensions.each { |e|
      puts "  #{e.name}\t#{e.description}"
    }
    Process.exit
  elsif ( ARGV[0] == "--engines" ) # TODO check dependencies in better way
    puts "Installed engines:"
    engines.each { |t|
      if ( `which #{t.name}` != "" )
        print "  #{t.name}\t#{t.description}"
        if ( t.name == params[:engine] )
          print " (default)"
        end
        puts ""
      end
    }
    Process.exit
  end

  # At this point, we are sure we want to compile -- process arguments!
  begin
    params.processArgs(ARGV)
  rescue ParameterException => e
    puts "#{shortcode} #{e.message}"
    Process.exit
  end

  # Kill command line parameters in order to discourage abuse by extensions
  ARGV.clear

  # Switch working directory to jobfile residence
  Dir.chdir(params[:jobpath])

  # Find used engine
  #  Note: always succeeds, we check for that in ParameterManager::processArgs
  engine = nil
  engines.each { |t|
    if ( t.name.to_sym == params[:engine] )
      engine = t
      break
    end
  }

  if ( `which #{params[:engine]}` == "" ) # TODO make obsolete by proper dependency check
    puts "#{shortcode} Engine not available. Please install #{params[:engine]} and make sure it is in the executable path."
    Process.exit
  end

  # Make sure that target directory is available
  if ( !File.exist?(params[:tmpdir]) )
    Dir.mkdir(params[:tmpdir])
  elsif ( !File.directory?(params[:tmpdir]) )
    puts "#{shortcode} File #{params[:tmpdir]} exists but is no directory"
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

  $ignoredfiles = ["#{ignorefile}#{params[:jobname]}",
                   "#{params[:tmpdir]}", 
                   "#{params[:jobname]}.#{engine.extension}",
                   "#{params[:log]}",
                   "#{params[:jobname]}.err",
                   ".listen_test"] # That is some artifact of listen -.-
  # Write ignore list for other processes
  File.open("#{ignorefile}#{params[:jobname]}", "w") { |file| 
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
  if ( params[:daemon] )
    begin
      gem "listen", ">=2.2.0"
      require 'listen'
    rescue Gem::LoadError
      params[:daemon] = false
      print "#{shortcode} Daemon mode requires gem 'listen'"
      
      begin
        gem "listen"
        puts " 2.2.0 or higher."
      rescue Gem::LoadError
        puts "."
      end
      
      puts (" " * shortcode.length) + 
           " Please install the latest version with 'gem install listen'."
    end
  end
  
  # Setup daemon mode
  if ( params[:daemon] )
    # Main listener: this one checks job files for changes and prompts recompilation.
    #                (indirectly: The Loop below checks $changetime.)
    $jobfilelistener = 
      Listen.to('.',
                latency: 0.5,
                ignore: [ /(\.\/)?#{Regexp.escape(ignorefile)}[^\/]+/,
                          /\A(\.\/)?(#{$ignoredfiles.map { |s| Regexp.escape(s) }.join("|")})/ ],
               ) \
      do |modified, added, removed|
        $changetime = Time.now
      end

    # Secondary listener: this one checks for (new) ignore files, i.e. other
    #                     jobs in the same directory. It then updates the main
    #                     listener so that it does not react to changes in files
    #                     generated by the other process.   
    $ignfilelistener = 
      Listen.to('.',
                # filter: /\A(\.\/)?#{Regexp.escape(ignorefile)}[^\/]+/,
                # Deprecated since listen 2.0.0.
                # This should be equivalent:
                ignore: /\A(?!(\.\/)?#{Regexp.escape(ignorefile)}).*/,
                latency: 0.1
               ) \
      do |modified, added, removed|
        $jobfilelistener.pause
        
        added.each { |ignf|
          files = ignoremore(ignf)
          $jobfilelistener.ignore(/\A(\.\/)?(#{files.map { |s| Regexp.escape(s) }.join("|")})/)
        }

        # TODO If another daemon terminates we keep its ignorefiles. Potential leak!
        #      If this turns out to be a problem, update list & listener (from scratch)
        
        $jobfilelistener.unpause
      end

    $ignfilelistener.start
    $changetime = Time.now
    $jobfilelistener.start
  end

  begin # demon loop
    begin # inner block that can be cancelled by user
      # Reset
      engine.heap = []
      log = Log.new(params) # TODO check dependencies
      log.level = params[:loglevel]
      start_time = Time.now

      # Copy all files to tmp directory (some LaTeX packages fail to work with output dir)
      exceptions = $ignoredfiles + $ignoredfiles.map { |s| "./#{s}" } + [".", ".."]

      Dir.entries(".").delete_if { |f| exceptions.include?(f) }.each { |f|
        # Avoid trouble with symlink loops
        if ( File.symlink?(f) )
          if ( !File.exists?("#{params[:tmpdir]}/#{f}") )
            File.symlink("../#{f}", "#{params[:tmpdir]}/#{f}")
          end
        else
          FileUtils::rm_rf("#{params[:tmpdir]}/#{f}")
          FileUtils::cp_r(f,"./#{params[:tmpdir]}/")
        end
      }

      # Move into temporary directory
      Dir.chdir(params[:tmpdir])

      # Delete former results in order not to pretend success
      if ( File.exist?("#{params[:jobname]}.#{engine.extension}") )
        FileUtils::rm("#{params[:jobname]}.#{engine.extension}")
      end

      # First engine run
      print "#{shortcode} #{engine.name}(1) #{running} ..."
      STDOUT.flush
      r = engine.exec
      puts " #{if r[0] then done else error end}"
      STDOUT.flush

      if ( engine.do? && File.exist?("#{params[:jobname]}.#{engine.extension}") )
        # The first run produced some output so the input is hopefully
        # not completely broken -- continue with the work!
        # (That is, if the engine says it wants to run again.)
      
        # Save the first log if it is the last one (should be before the extensions)
        if ( params[:ltxruns] ==  1 )
          log.add_messages(engine.name, :engine, r[1], r[2])
        end

        # Read hashes
        $hashes = {}
        hashfile = hashes
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
        while (  (params[:ltxruns] > 0 && run <= params[:ltxruns]) ||
                 (params[:ltxruns] <= 0 && engine.do?) )
          print "#{shortcode} #{engine.name}(#{run}) #{running} ..."
          STDOUT.flush
          r = engine.exec
          puts " #{if r[0] then done else error end}"
          STDOUT.flush
          run += 1
        end

        # Save the last log if we did not save it already
        if ( params[:ltxruns] !=  1 )
          log.add_messages(engine.name, :engine, r[1], r[2])
        end
      else
        # First run did not yield a result so there has been a fatal error.
        # Don't bother with extensions or more runs, just stop and
        # report failure.
        log.add_messages(engine.name, :engine, r[1], r[2])
      end

      # Write new hashes
      File.open(hashes, "w") { |file|
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
      if ( File.exist?("#{params[:jobname]}.#{engine.extension}") )
        FileUtils::cp("#{params[:jobname]}.#{engine.extension}","../")
        puts "#{shortcode} Output generated at #{params[:jobname]}.#{engine.extension}"
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
        
        target = params[:log]
        STDOUT.flush
        tmpsrc = "#{params[:log]}.#{params[:logformat].to_s}"
        log.to_s("#{params[:log]}.raw")
        
        mdfallback = false
        if ( params[:logformat] == :pdf )
          begin
            log.to_pdf("#{params[:log]}.pdf")
            
            # Sucks, but OS might not offer correct apps otherwise
            if ( !params[:log].end_with?(".pdf") )
              target = "#{params[:log]}.pdf"
            end
          rescue RuntimeError => e
            puts "\n#{shortcode} Failed to build PDF log:\n" +
                 (" " * shortcode.length) + " " + e.message
                 
            # Fall back to Markdown log
            print "#{shortcode} Falling back to Markdown log ... "
            tmpsrc = "#{params[:log]}.md"
            mdfallback = true
          end
        end
        if ( params[:logformat] == :md || mdfallback )
          log.to_md("#{params[:log]}.md")
          
          # Sucks, but viewers can not choose proper highlighting otherwise
          if ( !params[:log].end_with?(".md") )
              target = "#{params[:log]}.md"
            end
        end
                
        FileUtils::cp(tmpsrc, "../#{target}")
        puts done
        puts "#{shortcode} Log file generated at #{target}"
        STDOUT.flush
        
        runtime = Time.now - start_time
        # Don't show runtimes of less than 5s (arbitrary)
        if ( runtime / 60 >= 1 || runtime % 60 >= 5 )
          puts "#{shortcode} Took #{sprintf("%d min ", runtime / 60)} #{sprintf("%d sec", runtime % 60)}"
        end
      end
    rescue Interrupt, SystemExit # User cancelled current run
      puts "\n#{shortcode} #{cancelled}"
    ensure 
      # Return from temporary directory
      Dir.chdir("..")
    end

    if ( params[:daemon] )
      # Wait until sources changes
      # TODO if check interval is negative (option to come), never wait.
      print "#{shortcode} Waiting for changes... "
       
      files = Thread.new do
        while ( $changetime <= start_time || Time.now - $changetime < 2 )
          sleep(0.5)
        end

        while ( Thread.current[:raisetarget] == nil ) do end
        Thread.current[:raisetarget].raise(Interrupt.new("Files have changed"))
      end
      files[:raisetarget] = Thread.current
      
      # Pause waiting if user wants to enter prompt 
      begin
        STDIN.noecho(&:gets)
        files.kill
        puts cancelled

        # Delegate. The method returns if the user
        # prompts a rerun. It throws a SystemExit
        # exception if the user wants to quit.
        DaemonPrompt.run(params)
      rescue Interrupt => e
        # We have file changes, rerun!
        puts "done"
      end
      
      # Rerun!
      puts ""
    end
  end while ( params[:daemon] )
rescue Interrupt, SystemExit
  puts "\n#{shortcode} Shutdown"
rescue Exception => e
  if ( params[:jobname] != nil )
    puts "\n#{shortcode} ERROR: #{e.message} (see #{params[:jobname]}.err for details)"
    File.open("#{params[:jobname]}.err", "w") { |file| 
      file.write("#{e.inspect}\n\n#{e.backtrace.join("\n")}") 
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
if ( params[:daemon] )
  $jobfilelistener.stop
  $ignfilelistener.stop
end

# Remove temps if so desired.
if ( params[:clean] )
  FileUtils::rm_rf(params[:tmpdir])
end
FileUtils::rm_rf("#{ignorefile}#{params[:jobname]}")
