$ext = Extension.new(
  "tikzext",

  "Compiles externalized TikZ images",

  { "ir" => [nil, "imagerebuild", "If set, externalised TikZ images are rebuilt."]},

  { "imagerebuild" => false },

  lambda { File.exist?("#{$jobname}.figlist") },

  lambda {
    # Command to process bibtex bibliography if necessary.
    # Uses the following variables:
    # * jobname -- name of the main LaTeX file (without file ending)
    pdflatex = '"pdflatex -shell-escape -file-line-error -interaction=batchmode -jobname \"#{fig}\" \"\\\def\\\tikzexternalrealjob{#{$jobname}}\\\input{#{$jobname}}\" 2>&1"'

    # TODO detect changes in **/*.tikz --> delete according PDF (?)

    log = ""
    number = Integer(`wc -l #{} #{$jobname}.figlist`.split(" ")[0].strip)
    c = 1

    # Run pdflatex for each figure
    # TODO parallelise
    IO.foreach("#{$jobname}.figlist") { |fig|
      fig = fig.strip

      if ( $params["imagerebuild"] || !File.exist?("#{fig}.pdf") )
        io = IO::popen(eval(pdflatex))
        output = io.readlines.join("").strip

        if ( !File.exist?("#{fig}.pdf") )
          log << "Error on #{fig}. See #{fig}.log \n"
        end
      end

      # Output up to ten dots
      if ( c % [1, (number / 10)].max == 0 )
        progress()
      end
      c += 1
    }

    # TODO check for errors/warnings
    return [true,log]
  })



