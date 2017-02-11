#!/usr/bin/ruby

# Pass this script the name of a TeX log and inspect the output
# for debugging TeXLogParser.

require '../lib/TeXLogParser.rb'

if ARGV.size < 1 || !File.exist?(ARGV[0])
  puts 'Usage: test_logparser.rb [tex.log]'
  Process.exit
end

File.open(ARGV[0], 'r') { |f|
  log = TeXLogParser::parse(f.readlines)
  puts log.map { |m| m.to_s }.join("\n\n")
}
