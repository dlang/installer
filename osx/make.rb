#!/usr/bin/env ruby

##
# Author:: Jacob Carlborg
# Version:: Initial created: 2009
# License:: Public Domain
#

require "fileutils"
require "optparse"

include FileUtils

class PackageMaker
	attr_accessor :path, :output
	
	def make
		dmd = ""
		dmd_conf = ""
		packagemaker = '/Developer/usr/bin/packagemaker'
		version = 0

		rm_rf "dmd"
		rm_rf "dmg"
		mkdir "dmd"
		wd = pwd

		Dir.chdir @path do
			cp_r %w( html license.txt man README.TXT license.txt samples src osx/bin osx/lib ), "#{wd}/dmd"
		end		
		
		if File.exist? "#{wd}/dmd/lib/libphobos2.a"
			version = 2
			dmd = "DMD2"
			dmd_conf = "dmd2.conf"
		else
			version = 1
			dmd = "DMD"
			dmd_conf = "dmd.conf"
		end
		
		cp dmd_conf, "dmd/bin/dmd.conf"		
		mkdir_p "dmg/#{dmd}"		
		cp "uninstall.command", "dmg/#{dmd}"

		# this works with PackageMaker 3.0.1 but doesn't seem to work with 3.0.3
		`#{packagemaker} -d dmd.pmdoc -o dmg/#{dmd}/#{dmd}.pkg` if version == 1
		`#{packagemaker} -d dmd2.pmdoc -o dmg/#{dmd}/#{dmd}.pkg` if version == 2
		`hdiutil create -srcfolder dmg/#{dmd} #{@output}.dmg` unless @output.nil?
		`hdiutil create -srcfolder dmg/#{dmd} dmd.dmg` if @output.nil? && version == 1
		`hdiutil create -srcfolder dmg/#{dmd} dmd2.dmg` if @output.nil? && version == 2
	end	
end

# Prints the message to stderr, exits
def die (*msg)
	$stderr.puts msg
	exit 1
end

if __FILE__ == $0
	maker = PackageMaker.new
	help_msg = "Use the `-h' flag or for help."	
	
	OptionParser.new do |opts|
		opts.banner = "Usage: #{File.basename(__FILE__)} [options]"
		opts.separator ""
		opts.separator "Options:"
		
		opts.on("-o", "--output FILENAME", "The filename of the dmg image, optional.") do |opt|
			maker.output = opt
		end
		
		opts.on("-d", "--dir DIRECTORY", "The path to the dmd directory, required.") do |opt|
			maker.path = opt
		end
		
		opts.on("-h", "--help", "Show this message.") do
			puts opts, help_msg
			exit
		end
		
		opts.separator ""
		opts.separator "Example:"
		opts.separator "./#{File.basename(__FILE__)} -d ~/Downloads/dmd -o dmd.1.045\n"
		
		if ARGV.empty?			
			die opts.banner
		else
			begin
				opts.parse!(ARGV)
				
				die "No path to dmd given" if maker.path.nil?
				
				maker.make
			rescue => e
				msg = e.message
				msg = "Internal error" if msg.empty?
				
				die msg, opts.banner, help_msg
			end
		end
	end
end