[
  Parameter.new(:user_jobname, "j", String, '"#{self[:jobname]}"',
                "Job name, in particular name of the resulting file."),
  Parameter.new(:clean, "c", Boolean, false,
                "If set, all intermediate results are deleted."),
  Parameter.new(:log, "l", String, '"#{self[:user_jobname]}.log"',
                "(Base-)Name of log file."),
  Parameter.new(:tmpdir, "t", String, '"#{self[:user_jobname]}#{TMPSUFFIX}"',
                "Directory for intermediate results")
].each { |p|
  ParameterManager.instance.addParameter(p)
}
