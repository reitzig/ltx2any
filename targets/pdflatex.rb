$tgt = Target.new(
  "pdflatex",

  "pdf",

  "Uses pdflatex to create a PDF",

  {},

  {},

  lambda { |parent|
    !parent.heap[0]
  },

  lambda { |parent|
    if ( parent.heap.size < 2 )
      parent.heap = [false, ""]
    end

    # Command for the main LaTeX compilation work.
    # Uses the following variables:
    # * jobfile -- name of the main LaTeX file (with file ending)
    # * tmpdir  -- the output directory
    pdflatex = '"pdflatex -file-line-error -interaction=nonstopmode #{$jobfile}"'

    f = IO::popen(eval(pdflatex))
    log = f.readlines
    # TODO fix equality check!

    newHash = -1
    if ( File.exist?("#{$jobname}.#{parent.extension}") )
      newHash = `cat #{$jobname}.#{parent.extension} | grep -a -v "/CreationDate\\|/ModDate\\|/ID" | md5sum`.strip
    end

    parent.heap[0] = parent.heap[1] == newHash
    parent.heap[1] = newHash

    # Implement error/warning detection
    return [true, log.join("")]
  }
)
