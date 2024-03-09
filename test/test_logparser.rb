#!/usr/bin/ruby
# frozen_string_literal: true

# Pass this script the name of a TeX log and inspect the output
# for debugging TeXLogParser.

require '../lib/TeXLogParser'

if ARGV.empty? || !File.exist?(ARGV[0])
  puts 'Usage: test_logparser.rb [tex.log]'
  Process.exit
end

File.open(ARGV[0], 'r') do |f|
  log = TeXLogParser.parse(f.readlines)
  puts log.map(&:to_s).join("\n\n")
end
