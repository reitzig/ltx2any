$ext = Extension.new(
  "makeindex",

  "Creates an index",

  {},

  {},

  lambda {
    File.exist?("#{$jobname}.idx")
  },

  lambda {
    # Command to create the index if necessary. Provide two versions,
    # one without and one with stylefile
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    # * mistyle -- name of the makeindex style file (with file ending)
    makeindex = { "default" => '"makeindex #{$jobname}"',
                  "styled"  => '"makeindex -s #{mistyle} #{$jobname}"'}
    progress(3)
  
    version = "default"
    mistyle = nil
    Dir["*.ist"].each { |f|
      version = "styled"
      mistyle = f
    }

    f = IO::popen(eval(makeindex[version]))
    log = f.readlines

    log << "\n\nFrom log file:\n\n"
    File.open("#{$jobname}.ilg", "r") { |file|
      while ( line = file.gets )
        log << line
      end
    }

    # TODO implement error/warning recognition
    # TODO build test case, validate
    return [true, log.join("")]
  })
