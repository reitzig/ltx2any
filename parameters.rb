[
  Parameter.new(:jobname, "j", String, nil,
                "Job name, in particular name of result file."),
  Parameter.new(:clean, "c", Boolean, false,
                "If set, all intermediate results are deleted."),
  Parameter.new(:log, "l", String, '"#{self[:jobname]}.log"',
                "(Base-)Name of log file."),
  Parameter.new(:tmpdir, "t", String, '"#{self[:jobname]}#{TMPSUFFIX}"',
                "Directory for intermediate results")
].each { |p|
  ParameterManager.instance.addParameter(p)
}
