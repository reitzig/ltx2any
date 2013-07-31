# Copyright 2010-2013, Raphael Reitzig
# <code@verrech.net>
# Version 2.0 beta
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

# Some frontend strings
name      = "ltx2any"
shortcode = "[#{name}]"
running   = "running"
done      = "Done"
error     = "Error"

begin
  puts "#{shortcode} Initialising ..."
  require 'fileutils'

  # Parameter codes, type, names and descriptions
  codes = {
    "t" => ["string", "tmpdir",   "Directory for intermediate results"],
    "l" => ["string", "log"   ,   "Name of log file"],
    "n" => ["int", "ltxruns",     "How often the LaTeX compiler runs. Values\n" +
                              "\t\tsmaller than 1 will cause it to run until the\n" +
                              "\t\tresulting file no longer changes."],
    "c" => [nil, "clean",         "If set, all intermediate results are deleted."],
    "o" => ["string", "target",   "The output target format. Call with --targets for a list."],
    "d" => [nil, "daemon", "Reruns ltx2any automatically when files change."]
  }

  # Parameter default values
  $params = {
    "tmpdir"    => '"#{$jobname}_tmp"',
    "log"       => '"#{$jobname}.log"',
    "hashes"    => ".hashes",
    "ltxruns"   => 0,
    "clean"     => false,
    "target"    => "pdflatex",
    "daemon"    => false
  }

  # Load all extensions
  require "#{File.dirname(__FILE__)}/Extension.rb"
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

  # Load all targets
  require "#{File.dirname(__FILE__)}/Target.rb"
  targets = []
  $tgt = nil
  Dir[File.dirname(__FILE__) + '/targets/*.rb'].sort.each { |f|
    load(f)

    if ( $tgt != nil && $tgt.kind_of?(Target) )
      targets.push($tgt)
    end

    $tgt = nil
  }

  # process command line parameters
  if ( ARGV.length == 0 || !(/--help|-help|--h|-h|help|\?/ !~ ARGV[0]) )
    puts "\nUsage: "
    puts "  #{name} [options] inputfile\tNormal execution (see below)"
    puts "  #{name} --extensions\t\tList of extensions"
    puts "  #{name} --targets\t\tList of target formats"
    puts "  #{name} --help\t\tThis message"

    puts "\nOptions:"
    codes.keys.sort.each { |key|
      puts "  -#{key}\t#{if ( codes[key][0] != nil ) then codes[key][0] end}\t#{codes[key][2]}"
    }

    Process.exit
  elsif ( ARGV[0] == "--extensions" )
    puts "Installed extensions in order of execution:"
    extensions.each { |e|
      puts "  #{e.name}\t#{e.description}"
    }
    Process.exit
  elsif ( ARGV[0] == "--targets" )
    puts "Installed targets:"
    targets.each { |t|
      puts "  #{t.name}\t#{t.description}"
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
    if ( !(/\A".+?"\z/ !~ $params["tmpdir"]) )
      $params["tmpdir"] = eval($params["tmpdir"])
    end
    # If the log string can be evaluated, do so
    if ( !(/\A".+?"\z/ !~ $params["log"]) )
      $params["log"] = eval($params["log"])
    end
  end

  # Kill command line parameters in order to discourage abuse by extensions
  ARGV.clear

  # Find used target
  target = nil
  targets.each { |t|
    if ( t.name == $params["target"] )
      target = t
      break
    end
  }
  if ( target == nil )
    puts "#{shortcode} No such target: #{$params["target"]}. Use --targets to list availabe targets."
    Process.exit
  end

  # Make sure that target directory is available
  if ( !File.exist?($params["tmpdir"]) )
    Dir.mkdir($params["tmpdir"])
  elsif ( !File.directory?($params["tmpdir"]) )
    puts "#{shortcode} File #{$params["tmpdir"]} exists but is no directory"
    Process.exit
  end

  # Hash function that can be used by targets and extensions
  require 'digest'
  def filehash(f)
    Digest::MD5.file(f).to_s
  end

  # Some helper functions
  def log(l)
    @summary << l
  end

  def startSection(name)
    @summary << "\n\n# # # # #\n"
    @summary << "# Running #{name}"
    @summary << "\n# # # # #\n\n"
  end

  def endSection(name)
    @summary << "\n\n# # # # #\n"
    @summary << "# Finished #{name}"
    @summary << "\n# # # # #\n\n"
  end

  def progress(steps=1)
    print "." * steps
    STDOUT.flush
  end

  def changeevent()
    @changetime = Time.now
  end

  # Setup file listener
  if ( $params['daemon'] )
    require 'rubygems'
    require 'listen'

    callback = Proc.new do |modified, added, removed|
      changeevent()
    end
    @changetime = Time.now
    @listener = Listen.to('.') \
                      .ignore(/(\.\/)?#{Regexp.escape($params['tmpdir'])}/, 
                              /(\.\/)?#{Regexp.escape($params["log"])}/, 
                              /(\.\/)?#{Regexp.escape("#{$jobname}.#{target.extension}")}/ \
                             ) \
                      .latency(0.5) \
                      .change(&callback)
    @listener.start
  end

  begin # demon loop
    begin # inner block that can be cancelled by user
      # Reset
      target.heap = []
      @summary = ""
      start_time = Time.now

      # Copy all files to tmp directory (some LaTeX packages fail to work with output dir)
      exceptions = [".", "..", $params["tmpdir"], $params["log"]]
      exceptions = exceptions + exceptions.map { |s| "./#{s}" }

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

      # Delete former results in order not to pretend success
      if ( File.exist?("#{$params["tmpdir"]}/#{$jobname}.#{target.extension}") )
        FileUtils::rm("#{$params["tmpdir"]}/#{$jobname}.#{target.extension}")
      end

      # Move into temporary directory
      Dir.chdir($params["tmpdir"])

      # First run of LaTeX compiler
      print "#{shortcode} #{target.name}(1) #{running} ..."
      STDOUT.flush
      r = target.exec
      puts " #{if r[0] then done else error end}"
      STDOUT.flush

      # Save the first log if it is the last one (should be before the extensions)
      if ( $params["ltxruns"] ==  1 )
        startSection(target.name)
        log(r[1])
        endSection(target.name)
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
        if ( e.do?() )
          startSection(e.name)
          print "#{shortcode} #{e.name} #{running} "
          STDOUT.flush
          r = e.exec()
          log(r[1])
          puts " #{if r[0] then done else error end}"
          STDOUT.flush
          endSection(e.name)
        end
      }

      # Run LaTeX compiler specified number of times or target says it's done
      run = 2
      while (   ($params["ltxruns"] > 0 && run <= $params["ltxruns"]) || ($params["ltxruns"] <= 0 && target.do?) )
        print "#{shortcode} #{target.name}(#{run}) #{running} ..."
        STDOUT.flush
        r = target.exec
        puts " #{if r[0] then done else error end}"
        STDOUT.flush
        run += 1
      end

      # Save the last log if we did not save it already
      if ( $params["ltxruns"] !=  1 )
        startSection(target.name)
        log(r[1])
        endSection(target.name)
      end

      # Write new hashes
      File.open(hashfile, "w") { |file|
        Dir.entries(".").sort.each { |f|
          if ( File::file?(f) )
            file.write(f + "," + filehash(f) + "\n")
          end
        }
      }
      
      # Pick up output if present
      if ( File.exist?("#{$jobname}.#{target.extension}") )
        FileUtils::cp("#{$jobname}.#{target.extension}","../")
        puts "#{shortcode} Output generated at #{$jobname}.#{target.extension}"
      else
        puts "#{shortcode} No output generated due to errors"
      end
      
      runtime = Time.now - start_time
      puts "#{shortcode} Took #{sprintf("%d min ", runtime / 60)} #{sprintf("%d sec", runtime % 60)}"
    rescue Interrupt # User cancelled current run
      puts "\n#{shortcode} Cancelled"
    ensure 
      # Return from temporary directory
      Dir.chdir("..")
    end

    # Write log
    if ( @summary != "" )
      File.open($params["log"], "w") { |file| file.write(@summary) }
      puts "#{shortcode} Log file generated at #{$params["log"]}"
    end

    if ( $params['daemon'] )
      # Wait until sources changes
      puts "#{shortcode} Waiting for changes... (^c to terminate)"
      while ( @changetime <= start_time || Time.now - @changetime < 2 )
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
  end
  # Exit immediately. Don't clean up, logs may be necessary for debugging.
  Kernel.exit!(FALSE) 
end

# Remove temps if so desired.
if ( $params["clean"] )
  FileUtils::rm_rf($params["tmpdir"])
end


