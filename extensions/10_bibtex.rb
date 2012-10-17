$ext = Extension.new(
  "bibtex",

  "Creates bibliography",

  {},

  {},

  lambda {
    found = false
    File.open("#{$jobname}.aux", "r") { |file|
      while ( line = file.gets )
        if ( !(/^\\bibdata\{.+?\}$/ !~ line) )
          found = true
        end
      end
    }

    if ( found )
      # check wether !File.exist?("#{$jobname}.bbl")
      # check wether `cat mathesis.aux | grep -e '^\\\\bib'` has changed
      # check wether ?.bib has changed
    end

    return found
  },

  lambda {
    # Command to process bibtex bibliography if necessary.
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    bibtex = '"bibtex #{$jobname}"'
    progress(3)

    f = IO::popen(eval(bibtex))
    log = f.readlines

    # TODO check for errors/warnings
    return [true,log.join("")]
  })
