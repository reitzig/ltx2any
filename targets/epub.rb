$tgt = Target.new(
  "epub",

  "epub",

  "\tCreates an epub ebook (Dummy)",

  {},

  {},

  lambda { |parent|
    false
  },

  lambda { |parent|
    # TODO implement
    return [false, "Dummy"]
  }
)
