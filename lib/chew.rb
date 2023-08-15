# frozen_string_literal: true

require 'constants'

# The main module.
# TODO: Meaningful doc with links to important places
module Chew
  # Load Managers first so other classes can add their dependencies and hooks
  Dir["#{BASEDIR}/#{LIBDIR}/*Manager.rb"].each(&method(:require))
  # Load rest of the utility classes
  Dir["#{BASEDIR}/#{LIBDIR}/*.rb"].each(&method(:require))

  # Load active components
  require "#{BASEDIR}/#{ENGDIR}/engine.rb"
  Dir["#{BASEDIR}/#{ENGDIR}/*.rb"].each(&method(:require))
  require "#{BASEDIR}/#{EXTDIR}/extension.rb"
  Dir["#{BASEDIR}/#{EXTDIR}/*.rb"].each(&method(:require))
  require "#{BASEDIR}/#{LOGWDIR}/log_writer.rb"
  Dir["#{BASEDIR}/#{LOGWDIR}/*.rb"].each(&method(:require))

  ENGINES = [
    Engines::LuaLaTeX,
    Engines::PdfLaTeX,
    Engines::XeLaTeX
  ].freeze

  ParameterManager.instance.addParameter(Parameter.new(
    :engine, 'e', ENGINES.map(&:to_sym), :pdflatex,
    'The output engine. Call with --engines for a list.'))

  EXTENSIONS = [
    # Note: the order is the one used during execution!
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
