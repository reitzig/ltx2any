# Copyright 2010-2018, Raphael Reitzig
# <code@verrech.net>
# Version 0.9 beta
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

# Add the base directory to the load path
$LOAD_PATH.unshift(File.expand_path(__dir__)) unless
  $LOAD_PATH.include?(__dir__) || $LOAD_PATH.include?(File.expand_path(__dir__))

require 'constants'

# Set process name to something less cumbersome
# $0=NAME

# Load stuff from the standard library
require 'digest'
require 'fileutils'
require 'io/console'
require 'singleton'
require 'yaml'

# Load gems
require 'bundler'
Dir.chdir(BASEDIR)
Bundler.require(:default)
Dir.chdir(WORKDIR)

# Load Managers first so other classes can add their dependencies and hooks
Dir["#{BASEDIR}/#{LIBDIR}/*Manager.rb"].each { |f| require f }
# Set up core parameters
PARAMS = ParameterManager.instance
require 'parameters'
# Load rest of the utility classes
Dir["#{BASEDIR}/#{LIBDIR}/*.rb"].each { |f| require f }

# Initialize CLI output wrapper
OUTPUT = Output.instance

# Freeze parameters
ARGV.freeze

Process.exit if CliHelp.instance.provideHelp(ARGV)

CLEAN = []
CLEANALL = []
begin
  # At this point, we are sure we want to compile -- process arguments!
  begin
    PARAMS.processArgs(ARGV)
  rescue ParameterException => e
    OUTPUT.separate.msg(*e.message.split("\n"))
    Process.exit
  end

  # Make sure all essential dependencies of core and engine are satisfied
  begin
    missing = []

    (DependencyManager.list(source: :core, relevance: :essential) +
     DependencyManager.list(source: [:engine, PARAMS[:engine].to_s], relevance: :essential)).each do |d|
      missing.push(d) unless d.available?
    end

    unless missing.empty? # TODO: enter into log?
      OUTPUT.separate.error('Missing dependencies', *missing)
      Process.exit
    end
  end

  # Check soft dependencies of core and engine; notify user if necessary
  begin
    missing = []

    (DependencyManager.list(source: :core, relevance: :recommended) +
     DependencyManager.list(source: [:engine, PARAMS[:engine].to_s], relevance: :recommended)).each do |d|
      missing.push(d) unless d.available?
    end

    OUTPUT.separate.warn('Missing dependencies', *missing) unless missing.empty? # TODO: enter into log?
  end

  # Switch working directory to jobfile residence
  Dir.chdir(PARAMS[:jobpath])
  CLEAN.push(PARAMS[:tmpdir])

  # Some files we don't want to listen to
  toignore = ["#{PARAMS[:tmpdir]}",
              "#{PARAMS[:user_jobname]}.#{Engine[PARAMS[:engine]].extension}",
              "#{PARAMS[:log]}",
              "#{PARAMS[:user_jobname]}.err"] + PARAMS[:ignore].split(':')

  begin
    FileListener.instance.start(PARAMS[:user_jobname], toignore) if PARAMS[:daemon]
  rescue MissingDependencyError => e
    OUTPUT.warn(e.message)
    PARAMS[:daemon] = false
  end

  begin # daemon loop
    begin # inner block that can be cancelled by user
      # Reset
      # @type [Engine] engine The engine we're running
      # @type [Log] log The main log
      # @type [Time] start_time The time at which the current run started
      engine = Engine[PARAMS[:engine]].new
      log = Log.new
      log.level = PARAMS[:loglevel]
      start_time = Time.now

      OUTPUT.start('Copying files to tmp')
      # Copy all files to tmp directory (some LaTeX packages fail to work with
      # output dir) excepting those we ignore anyways.
      # Oh, and don't recurse outside the main directory, duh.
      ignore = FileListener.instance.ignored + toignore
      exceptions = ignore + ignore.map { |s| "./#{s}" } +
                   Dir['.*'] + Dir['./.*'] # drop hidden files, in p. . and ..

      define_singleton_method(:copy2tmp) do |files|
        files.each do |f|
          if File.symlink?(f)
            # Avoid trouble with symlink loops

            # Delete old symlink if there is one, because:
            # If a proper file or directory has been replaced with a symlink,
            # remove the obsolete stuff.
            # If there already is a symlink, delete because it might have been
            # relinked.
            FileUtils.rm("#{PARAMS[:tmpdir]}/#{f}") if File.exist?("#{PARAMS[:tmpdir]}/#{f}")

            # Create new symlink instead of copying
            File.symlink("#{PARAMS[:jobpath]}/#{f}", "#{PARAMS[:tmpdir]}/#{f}")
          elsif File.directory?(f)
            FileUtils.mkdir_p("#{PARAMS[:tmpdir]}/#{f}")
            copy2tmp(Dir.children(f).map { |s| "#{f}/#{s}" })
            # TODO: Is this necessary? Why not just copy? (For now, safer and more adaptable.)
          else
            FileUtils.cp(f, "#{PARAMS[:tmpdir]}/#{f}")
          end
        end
      end

      # tmp dir may have been removed (either by DaemonPrompt or the outside)
      if !File.exist?(PARAMS[:tmpdir])
        FileUtils.mkdir_p(PARAMS[:tmpdir])
      elsif !File.directory?(PARAMS[:tmpdir])
        OUTPUT.message("File #{PARAMS[:tmpdir]} exists but is not a directory")
        Process.exit
      end

      # (Re-)Copy content to tmp
      copy2tmp(Dir.children('.').reject { |f| exceptions.include?(f) })
      OUTPUT.stop(:success)

      # Move into temporary directory
      Dir.chdir(PARAMS[:tmpdir])

      # Delete former results in order not to pretend success
      FileUtils.rm("#{PARAMS[:jobname]}.#{engine.extension}") if File.exist?("#{PARAMS[:jobname]}.#{engine.extension}")

      # Read hashes
      HashManager.instance.from_file("#{HASHFILE}")

      # Run extensions that may need to do something before the engine
      Extension.run_all(:before, OUTPUT, log)

      # Run engine as often as specified
      run = 1
      result = []
      loop do
        # Run engine
        OUTPUT.start("#{engine.name}(#{run}) running")
        result = engine.exec
        OUTPUT.stop(result[:success] ? :success : :error)

        break unless File.exist?("#{PARAMS[:jobname]}.#{engine.extension}")

        # Run extensions that need to do something after this iteration
        Extension.run_all(run, OUTPUT, log)

        run += 1
        break if (PARAMS[:engineruns] > 0 && run > PARAMS[:engineruns]) || # User set number of runs
                 (PARAMS[:engineruns] <= 0 && !engine.do?) # User set automatic mode
      end

      # Save log messages of last engine run
      log.add_messages(engine.name, :engine, result[:messages], result[:log])

      # Run extensions that may need to do something after all engine runs
      Extension.run_all(:after, OUTPUT, log)

      # Give error/warning counts to user
      errorS = log.count(:error) == 1 ? '' : 's'
      warningS = log.count(:warning) == 1 ? '' : 's'
      OUTPUT.msg("There were #{log.count(:error)} error#{errorS} " +
                 "and #{log.count(:warning)} warning#{warningS}.")

      # Pick up output if present
      if File.exist?("#{PARAMS[:jobname]}.#{engine.extension}")
        FileUtils.cp("#{PARAMS[:jobname]}.#{engine.extension}",
                     "#{PARAMS[:jobpath]}/#{PARAMS[:user_jobname]}.#{engine.extension}")
        OUTPUT.msg("Output generated at #{PARAMS[:user_jobname]}.#{engine.extension}")
      else
        OUTPUT.msg('No output generated, probably due to fatal errors.')
      end

      # Write log
      unless log.empty?
        OUTPUT.start('Assembling log files')

        # Manage messages from extensions
        Extension.list.each do |ext|
          if !log.has_messages?(ext.name) && File.exist?(".#{NAME}_extensionmsg_#{ext.name}")
            # Extension did not run but has run before; load messages from then!
            old = File.open(".#{NAME}_extensionmsg_#{ext.name}", 'r') do |f|
              f.readlines.join
            end
            old = YAML.load(old)
            log.add_messages(ext.name, old[0], old[1], old[2])
          elsif log.has_messages?(ext.name)
            # Write new messages
            File.write(".#{NAME}_extensionmsg_#{ext.name}", YAML.dump(log.messages(ext.name)))
          end
        end

        log.finish
        logfile = LogWriter[:raw].write(log)
        logfile = LogWriter[PARAMS[:logformat]].write(log, PARAMS[:loglevel])

        FileUtils.cp(logfile, "#{PARAMS[:jobpath]}/#{logfile}")
        OUTPUT.stop(:success)
        OUTPUT.msg("Log file generated at #{logfile}")
        CLEANALL.push("#{PARAMS[:jobpath]}/#{logfile}")
        CLEANALL.uniq!

        runtime = Time.now - start_time
        # Don't show runtimes of less than 5s (arbitrary)
        if runtime / 60 >= 1 || runtime % 60 >= 5
          OUTPUT.msg("Took #{format('%d min ', runtime / 60)} #{format('%d sec', runtime % 60)}")
        end
      end
    rescue Interrupt, SystemExit # User cancelled current run
      OUTPUT.stop(:cancel)
    rescue Exception => e
      OUTPUT.stop(:error)
      raise e
    ensure
      # Return from temporary directory
      Dir.chdir(PARAMS[:jobpath])
    end

    FileListener.instance.waitForChanges(OUTPUT) if PARAMS[:daemon] && PARAMS[:listeninterval] > 0

    # Rerun!
    OUTPUT.separate
  end while (PARAMS[:daemon])
rescue Interrupt, SystemExit
  OUTPUT.separate.msg('Shutdown')
rescue Exception => e
  raise e if PARAMS[:user_jobname].nil?

  OUTPUT.separate.error(e.message, "See #{PARAMS[:user_jobname]}.err for details.")
  File.write("#{PARAMS[:jobpath]}/#{PARAMS[:user_jobname]}.err", "#{e.inspect}\n\n#{e.backtrace.join("\n")}")
  CLEANALL.push("#{PARAMS[:jobpath]}/#{PARAMS[:user_jobname]}.err")

  # This is reached due to programming errors or if ltx2any quits early,
  # i.e. if no feasible input file has been specified.
  # Neither case warrants special action.
  # For debugging purposes, reraise so we don't die silently.

  # Exit immediately. Don't clean up, logs may be necessary for debugging.
  # Kernel.exit!(FALSE) # Leads to inconsistent behaviour regarding -c/-ca
end

# Write current hashes
HashManager.instance.to_file("#{PARAMS[:tmpdir]}/#{HASHFILE}") if !PARAMS[:clean] && !HashManager.instance.empty?
# NOTE: old version stored hashes for *all* files. Now we only store such
#       that were needed earlier. Is that sufficient?

# Stop file listeners
FileListener.instance.stop if PARAMS[:daemon] && FileListener.instance.runs?
# Remove temps if so desired.
CLEAN.each    { |f| FileUtils.rm_rf(f) } if PARAMS[:clean]
CLEANALL.each { |f| FileUtils.rm_rf(f) } if PARAMS[:cleanall]
