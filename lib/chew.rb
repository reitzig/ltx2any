require 'constants'

module Chew
  # Load Managers first so other classes can add their dependencies and hooks
  Dir["#{BASEDIR}/#{LIBDIR}/*Manager.rb"].each { |f| require f }
  # Load rest of the utility classes
  Dir["#{BASEDIR}/#{LIBDIR}/*.rb"].each { |f| require f }

  # Load active components
  require "#{BASEDIR}/#{ENGDIR}/engine.rb"
  Dir["#{BASEDIR}/#{ENGDIR}/*.rb"].each { |f| require f }
  require "#{BASEDIR}/#{EXTDIR}/extension.rb"
  Dir["#{BASEDIR}/#{EXTDIR}/*.rb"].each { |f| require f }
  require "#{BASEDIR}/#{LOGWDIR}/log_writer.rb"
  Dir["#{BASEDIR}/#{LOGWDIR}/*.rb"].each { |f| require f }

  ENGINES = [
    Engines::LuaLaTeX,
    Engines::PdfLaTeX,
    Engines::XeLaTeX
  ].freeze

  EXTENSIONS = [
    Extensions::Biber,
    Extensions::BibTeX,
    Extensions::MakeIndex,
    Extensions::MetaPost,
    Extensions::SageTeX,
    Extensions::TikZExt,
    Extensions::Gnuplot,
    Extensions::SyncTeX
  ].freeze

  LOG_FORMATS = [
    LogWriters::Json,
    LogWriters::LaTeX,
    LogWriters::Markdown,
    LogWriters::PDF,
    LogWriters::Raw
  ].freeze
end

# TODO: refactor

# Add engine-related parameters
ParameterManager.instance.addParameter(Parameter.new(
  :engine, 'e', Chew::ENGINES.map { |e| e.to_sym }, :pdflatex,
  'The output engine. Call with --engines for a list.'))
ParameterManager.instance.addParameter(Parameter.new(
  :enginepar, 'ep', String, '',
  'Parameters passed to the engine, separated by spaces.'))
ParameterManager.instance.addParameter(Parameter.new(
  :engineruns, 'er', Integer, 0,
  'How often the LaTeX engine runs. Values smaller than one will cause it to run until the resulting file no longer changes. May not apply to all engines.'))

# Add log-writer-related parameters
[
  Parameter.new(:log, 'l', String, '"#{self[:user_jobname]}.log"',
                '(Base-)Name of log file'),
  Parameter.new(:logformat, 'lf', Chew::LOG_FORMATS.map(&:to_sym), :md,
                'The log format. Call with --logformats for a list.'),
  Parameter.new(:loglevel, 'll', [:error, :warning, :info], :warning,
                "Set to 'error' to see only errors, to 'warning' to also see warnings, or to 'info' for everything.")
].each { |p| ParameterManager.instance.addParameter(p) }