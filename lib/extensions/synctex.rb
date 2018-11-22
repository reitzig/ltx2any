# Copyright 2010-2018, Raphael Reitzig
#
# This file is part of chew.
#
# chew is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# chew is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with chew. If not, see <http://www.gnu.org/licenses/>.

require 'zlib'

ParameterManager.instance.addParameter(Parameter.new(
  :synctex, 'synctex', Boolean, false, 'Set to make engines create SyncTeX files.'))

# Add hook that adapts the :enginepar parameter whenever :synctex changes (including startup)
ParameterManager.instance.addHook(:synctex) do |key, val|
  params = ParameterManager.instance

  # Set engine parameter
  # TODO: make nicer with array parameters
  parameter = '--synctex=-1'
  if val && params[:enginepar][parameter] == nil # TODO: what is the second access?
    params.add(:enginepar, parameter)
  elsif !val
    params[:enginepar] = params[:enginepar].gsub(parameter, '')
  end

  # Add synctex file to those that should be ignored
  # TODO: make nicer with array parameters
  synctexfile = "#{params[:jobname]}.synctex.gz"
  if val && params[:ignore] == nil
    params.add(:ignore, synctexfile)
  elsif val && params[:ignore].empty?
    params[:ignore] = synctexfile
  elsif val # && !params[:ignore].empty?
    params[:ignore] = params[:ignore] + ":#{synctexfile}"
  elsif !val
    params[:ignore] = params[:ignore].gsub(/:?#{synctexfile}/, '')
  end
end

module Chew
  module Extensions
    class SyncTeX
      include Extension

      def initialize
        super
        @name        = 'SyncTeX'
        @description = 'Provides support for SyncTeX'
      end

      def do?(time)
        ParameterManager.instance[:synctex] && time == :after
      end

      def exec(time, progress)
        params = ParameterManager.instance

        unless File.exist?("#{params[:jobname]}.synctex")
          return { success:  false,
                   messages: [TexLogParser::Message.new(message: 'SyncTeX file not found.', level: :error)],
                   log:      'SyncTeX file not found.' }
        end

        # Fix paths in synctex file, gzip it and put result in main directory
        Zlib::GzipWriter.open("#{params[:jobpath]}/#{params[:jobname]}.synctex.gz") do |gz|
          File.open("#{params[:jobname]}.synctex", 'r') do |f|
            f.readlines.each do |line|
              # Replace tmp path with job path.
              # Catch absolute tmp paths first, then try to match paths relative to job path.
              gz.write line.sub("#{params[:jobpath]}/#{params[:tmpdir]}", params[:jobpath])\
                       .sub(params[:tmpdir], params[:jobpath])
            end
          end
        end

        { success: true, messages: [], log: '' }
      end
    end
  end
end
