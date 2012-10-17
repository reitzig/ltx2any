$ext = Extension.new(
  "gnuplot",

  "Renders generated gnuplot files",

  {},

  {},

  lambda {
    !Dir.entries(".").delete_if { |f|
      (/\.gnuplot$/ !~ f) || ($hashes.has_key?(f) && filehash(f) == $hashes[f])
    }.empty?
  },

  lambda {
    # Command to process bibtex bibliography if necessary.
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    gnuplot = '"gnuplot #{f} 2>&1"'

    # Filter out non-gnuplot fieles and such that did not change since last run
    gnuplot_files = Dir.entries(".").delete_if { |f|
      (/\.gnuplot$/ !~ f) || ($hashes.has_key?(f) && filehash(f) == $hashes[f])
    }

    # Run gnuplot
    # TODO parallelise
    log = ""
    c = 1
    gnuplot_files.each { |f|
      io = IO::popen(eval(gnuplot))
      output = io.readlines.join("").strip

      if ( output != "" )
        log << "# #\n# #{f}\n\n"
        log << output + "\n\n"
      end

      # Output up to ten dots
      if ( c % [1, (gnuplot_files.size / 10)].max == 0 )
        progress()
      end
      c += 1
    }

    # TODO check for errors/warnings
    return [true,log]
  })
