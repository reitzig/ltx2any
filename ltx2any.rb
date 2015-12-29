# Copyright 2010-2015, Raphael Reitzig
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

# Set process name to something less cumbersome
$0="ltx2any.rb"

# Some frontend strings
# TODO move somewhere nice
name       = "ltx2any"
version    = "0.9a"
tmpsuffix  = "_tmp"
ignorefile = ".#{name}ignore_"
hashfile   = ".hashes" # relative to tmp directory

# Load stuff from standard library
require 'io/console'
require 'fileutils'
require 'yaml'

# Load these first so other classes can add their dependencies and hooks
require File.dirname(__FILE__) + '/lib/DependencyManager.rb'
require File.dirname(__FILE__) + '/lib/ParameterManager.rb'
  params = ParameterManager.instance
# Load rest of utility classes
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each { |f| require f } # TODO load dependencies
  output = Output.instance
  output.name = name

# Add global dependencies
DependencyManager.add("listen", :gem, :recommended, "for daemon mode")

begin
  output.start("Initialising")  
                                 
  # Load all extensions
  Dir[File.dirname(__FILE__) + '/extensions/*.rb'].sort.each { |f|
    if ( !(/^\d\d/ !~ File.basename(f)) )
      load(f)
    end
  }

  # Load all engines
  Dir[File.dirname(__FILE__) + '/engines/*.rb'].sort.each { |f|
    load(f)
  }

  params.addParameter(Parameter.new(:engine, "e", Engine.list.map { |e| e.to_sym }, :pdflatex,
                                    "The output engine. Call with --engines for a list."))

  # TODO Move code to the appropriate places, prettify
  # Check for help/usage commands
  if ( ARGV.length == 0 || /--help|--h/ =~ ARGV[0] )
    output.stop(:success)
    puts "\nUsage: "
    puts "  #{name} [options] inputfile\tNormal execution (see below)"
    puts "  #{name} --extensions\t\tList of extensions"
    puts "  #{name} --engines\t\tList of target engines"
    puts "  #{name} --dependencies\t\tList of dependencies"
    puts "  #{name} --version\t\tPrints version information"
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
  elsif ( ARGV[0] == "--extensions" )
    output.stop(:success)
    puts "Installed extensions in execution order:"
    maxwidth = Extension.list.map { |e| e.name.length }.max
    Extension.list.each { |e|
      puts "  #{e.name}#{" " * (maxwidth - e.name.length)}\t#{e.description}"
    }
    Process.exit
  elsif ( ARGV[0] == "--engines" )
    output.stop(:success)
    puts "Installed engines:"
    Engine.list.each { |e|
      if ( DependencyManager.available?(e.binary, :binary) )
        print "  #{e.name}\t#{e.description}"
        if ( e.to_sym == params[:engine] )
          print " (default)"
        end
        puts ""
      end
    }
    Process.exit
  elsif ( ARGV[0] == "--dependencies" )
    output.stop(:success)
    puts DependencyManager.to_s
    Process.exit
  elsif ( ARGV[0] == "--version" )
    output.stop(:success)
    puts "#{name} #{version}"
    puts "Copyright \u00A9 Raphael Reitzig 2015".encode('utf-8')
    puts "This is free software; see the source for copying conditions."
    puts "There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE."
    Process.exit
  end

  # At this point, we are sure we want to compile -- process arguments!
  begin
    params.processArgs(ARGV)
    # Kill command line parameters in order to discourage abuse by extensions
    ARGV.clear
  rescue ParameterException => e
    output.separate.msg(*e.message.split("\n"))
    Process.exit
  end

  # Make sure all essential dependencies are here
  begin
    DependencyManager.load_essentials
  rescue => e
    output.separate.msg(e.message)
    Process.exit
  end

  # Switch working directory to jobfile residence
  Dir.chdir(params[:jobpath])

  $ignoredfiles = ["#{ignorefile}#{params[:jobname]}",
                   "#{params[:tmpdir]}", 
                   "#{params[:jobname]}.#{Engine[params[:engine]].extension}",
                   "#{params[:log]}",
                   "#{params[:jobname]}.err"]
  # Write ignore list for other processes
  File.open("#{params[:jobpath]}/#{ignorefile}#{params[:jobname]}", "w") { |file| 
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
      msg = "#{shortcode} Daemon mode requires gem 'listen'"
      
      begin
        gem "listen"
        msg += " 2.2.0 or higher."
      rescue Gem::LoadError
        msg += "."
      end
      
      output.message(msg, "Please install the latest version with 'gem install listen'.")
    end
  end
  
  # Setup daemon mode
  $vanishedfiles = []
  if ( params[:daemon] )
    # Main listener: this one checks job files for changes and prompts recompilation.
    #                (indirectly: The Loop below checks $changetime.)
    $jobfilelistener = 
      Listen.to('.',
                latency: params[:listeninterval],
                ignore: [ /(\.\/)?#{Regexp.escape(ignorefile)}[^\/]+/,
                          #/(\.\/)?\..*/, # ignore hidden files, e.g. .git
                          /\A(\.\/)?(#{$ignoredfiles.map { |s| Regexp.escape(s) }.join("|")})/ ],
               ) \
      do |modified, added, removed|
        # TODO cruel hack; can we do better?
        removed.each { |r|
          $vanishedfiles.push File.path(r.to_s).sub(params[:jobpath], params[:tmpdir])
        }
        $changetime = Time.now
      end
      
    params.addHook(:listeninterval) { |key,val|
      # $jobfilelistener.latency = val
      # TODO tell change to listener; in worst case, restart?
    }

    # Secondary listener: this one checks for (new) ignore files, i.e. other
    #                     jobs in the same directory. It then updates the main
    #                     listener so that it does not react to changes in files
    #                     generated by the other process.   
    $ignfilelistener = 
      Listen.to('.',
                #only: /\A(\.\/)?#{Regexp.escape(ignorefile)}[^\/]+/,
                # TODO switch to `only` once listen 2.3 is available
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
  output.stop(:success)
  
  begin # daemon loop
    begin # inner block that can be cancelled by user
      # Reset
      engine = Engine[params[:engine]].new
      log = Log.new # TODO check dependencies
      log.level = params[:loglevel]
      start_time = Time.now

      output.start("Copying files to tmp")
      # Copy all files to tmp directory (some LaTeX packages fail to work with output dir)
      # excepting those we ignore anyways. Oh, and don't recurse outside the main
      # directory, duh.
      exceptions = $ignoredfiles + $ignoredfiles.map { |s| "./#{s}" } + 
                   Dir[".*"] + Dir["./.*"] # drop hidden files, in p. . and ..

      define_singleton_method(:copy2tmp) { |files| 
        files.each { |f|
          if ( File.symlink?(f) )
            # Avoid trouble with symlink loops
            
            # Delete old symlink if there is one, because:
            # If a proper file or directory has been replaced with a symlink,
            # remove the obsolete stuff.
            # If there already is a symlink, delete because it might have been
            # relinked.
            if ( File.exists?("#{params[:tmpdir]}/#{f}") )
              FileUtils::rm("#{params[:tmpdir]}/#{f}")
            end
            
            # Create new symlink instead of copying 
            File.symlink("#{params[:jobpath]}/#{f}", "#{params[:tmpdir]}/#{f}")
          elsif ( File.directory?(f) )
            FileUtils::mkdir_p("#{params[:tmpdir]}/#{f}")
            copy2tmp(Dir.entries(f)\
                        .delete_if { |s| [".", ".."]\
                        .include?(s) }.map { |s| "#{f}/#{s}" })
            # TODO Is this necessary? Why not just copy? (For now, safer and more adaptable.)
          else
            FileUtils::cp(f,"#{params[:tmpdir]}/#{f}")
          end
        }
      }

      # Remove files reported missing since last run from tmp (so we don't hide errors)
      # Be extra careful, we don't want to delete non-tmp files!
      $vanishedfiles.each { |f| FileUtils.rm_rf(f) if f.start_with?(params[:tmpdir]) && File.exists?(f) }
      
      # tmp dir may have been removed (either by DaemonPrompt or the outside)
      if ( !File.exist?(params[:tmpdir]) )
        FileUtils.mkdir_p(params[:tmpdir])
      elsif ( !File.directory?(params[:tmpdir]) )
        output.message("File #{params[:tmpdir]} exists but is no directory")
        Process.exit
      end

      # (Re-)Copy content to tmp
      copy2tmp(Dir.entries(".").delete_if { |f| exceptions.include?(f) })
      output.stop(:success)

      # Move into temporary directory
      Dir.chdir(params[:tmpdir])

      # Delete former results in order not to pretend success
      if ( File.exist?("#{params[:jobname]}.#{engine.extension}") )
        FileUtils::rm("#{params[:jobname]}.#{engine.extension}")
      end
      
      # Read hashes
      HashManager.instance.from_file("#{hashfile}")

      # First engine run
      output.start("#{engine.name}(1) running")
      r = engine.exec
      output.stop(if r[0] then :success else :error end)

      if ( engine.do? && File.exist?("#{params[:jobname]}.#{engine.extension}") )
        # The first run produced some output so the input is hopefully
        # not completely broken -- continue with the work!
        # (That is, if the engine says it wants to run again.)
      
        # Save the first log if it is the last one (should be before the extensions)
        if ( params[:runs] ==  1 )
          log.add_messages(engine.name, :engine, r[1], r[2])
        end
        
        # Run all extensions in order
        Extension.list.each { |e|
          e = e.new
          if ( e.do? ) # TODO check dependencies here?
            progress, stop = output.start("#{e.name} running", e.job_size)
            r = e.exec(progress)
            stop.call(if r[0] then :success else :error end)
            log.add_messages(e.name, :extension, r[1], r[2])
          end
        }

        # Run engine as often as specified/necessary
        run = 2
        while (  (params[:runs] > 0 && run <= params[:runs]) ||
                 (params[:runs] <= 0 && engine.do?) )
          output.start("#{engine.name}(#{run}) running")
          r = engine.exec
          output.stop(if r[0] then :success else :error end)
          run += 1
        end

        # Save the last log if we did not save it already
        if ( params[:runs] !=  1 )
          log.add_messages(engine.name, :engine, r[1], r[2])
        end
      else
        # First run did not yield a result so there has been a fatal error.
        # Don't bother with extensions or more runs, just stop and
        # report failure.
        log.add_messages(engine.name, :engine, r[1], r[2])
      end
      
      errorS = if ( log.count(:error) != 1 ) then "s" else "" end
      warningS = if ( log.count(:warning) != 1 ) then "s" else "" end
      output.msg("There were #{log.count(:error)} error#{errorS} " + 
                 "and #{log.count(:warning)} warning#{warningS}.")
      
      # Pick up output if present
      if ( File.exist?("#{params[:jobname]}.#{engine.extension}") )
        FileUtils::cp("#{params[:jobname]}.#{engine.extension}", "#{params[:jobpath]}/")
        output.msg("Output generated at #{params[:jobname]}.#{engine.extension}")
      else
        output.msg("No output generated, probably due to fatal errors.")
      end
            
      # Write log
      if ( !log.empty? )
        output.start("Assembling log files")
        
        # Manage messages from extensions
        Extension.list.each { |ext|
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
            output.stop(:error, "Failed to build PDF log:", e.message)
                 
            # Fall back to Markdown log
            output.start("Falling back to Markdown log")
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
                
        FileUtils::cp(tmpsrc, "#{params[:jobpath]}/#{target}")
        output.stop(:success)
        output.msg("Log file generated at #{target}")
        
        runtime = Time.now - start_time
        # Don't show runtimes of less than 5s (arbitrary)
        if ( runtime / 60 >= 1 || runtime % 60 >= 5 )
          output.msg("Took #{sprintf("%d min ", runtime / 60)} #{sprintf("%d sec", runtime % 60)}")
        end
      end
    rescue Interrupt, SystemExit # User cancelled current run
      output.stop(:cancel)
    ensure 
      # Return from temporary directory
      Dir.chdir(params[:jobpath])
    end

    if ( params[:daemon] )
      # Wait until sources changes
      # TODO if check interval is negative (option to come), never wait.
      output.start("Waiting for file changes")
       
      files = Thread.new do
        while ( $changetime <= start_time || Time.now - $changetime < 2 )
          sleep(params[:listeninterval])
        end

        while ( Thread.current[:raisetarget] == nil ) do end
        Thread.current[:raisetarget].raise(Interrupt.new("Files have changed"))
      end
      files[:raisetarget] = Thread.current
      
      # Pause waiting if user wants to enter prompt 
      begin
        STDIN.noecho(&:gets)
        files.kill
        output.stop(:cancel)

        # Delegate. The method returns if the user
        # prompts a rerun. It throws a SystemExit
        # exception if the user wants to quit.
        DaemonPrompt.run(params)
      rescue Interrupt => e
        # We have file changes, rerun!
        output.stop(:success)
      end
      
      # Rerun!
      output.separate
    end
  end while ( params[:daemon] )
rescue Interrupt, SystemExit
  output.separate.msg("Shutdown")
rescue Exception => e
  if ( params[:jobname] != nil )
    output.separate.msg("ERROR: #{e.message} (see #{params[:jobname]}.err for details)")
    File.open("#{params[:jobpath]}/#{params[:jobname]}.err", "w") { |file| 
      file.write("#{e.inspect}\n\n#{e.backtrace.join("\n")}") 
    }
  else
    # This is reached due to programming errors or if ltx2any quits early,
    # i.e. if no feasible input file has been specified.
    # Neither case warrants special action.
    # For debugging purposes, reraise so we don't die silently.
     raise e
  end
  # Exit immediately. Don't clean up, logs may be necessary for debugging.
  Kernel.exit!(FALSE) 
end

# Write current hashes
HashManager.instance.to_file("#{params[:tmpdir]}/#{hashfile}") if params[:jobname] != nil && !params[:clean]
# Note: old version stored hashes for *all* files. Now we only store such
#       that were needed earlier. Is that sufficient?

# Stop file listeners
if ( params[:daemon] )
  begin
    $jobfilelistener.stop
    $ignfilelistener.stop
  rescue Exception
    # Apparently, stopping throws exceptions.
  end
end

# Remove temps if so desired.
FileUtils::rm_rf(params[:tmpdir]) if params[:clean] 
FileUtils::rm_rf("#{params[:jobpath]}/#{ignorefile}#{params[:jobname]}")
