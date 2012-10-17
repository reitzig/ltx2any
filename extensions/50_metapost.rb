$ext = Extension.new(
  "metapost",

  "Parses metapost files (Dummy)",

  {},

  {},

  lambda {
    false # TODO implement
  },

  lambda {
    # Command to parse metapost files after first LaTeX run.
    # Make sure its parameterisation fits the used LaTeX compiler.
    # Uses the following variables:
    # * mpfile  -- the name of the metapost file to be parsed
    metapost = '"mpost -tex=pdflatex -interaction=nonstopmode #{mpfile}"'
    progress(3)

   # TODO implement
   return [false, "Dummy"]
  })
