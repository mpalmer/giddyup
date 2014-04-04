# Wrap all calls to external commands in appropriate class methods.
#
# Honestly, this is primarily for ease of testing, but I suppose if someone
# wanted to go hog-wild and replace this for some crazy use of GitDeploy, it
# might come in handy.
#
require 'open3'

module Giddyup; end

class Giddyup::CommandWrapper
	class CommandFailed < StandardError
		attr_reader :status, :output

		def initialize(status, output)
			@status = status
			@output = output
			super("Command execution failed")
		end
	end

	# Run a command and return the output of the command as an array
	# containing elements of the following form:
	#
	# [<stream>, <line>]
	#
	# Where <stream> is either :stdout or :stderr (to indicate which output
	# stream the line came from), and <line> is the line of text (sans
	# trailing newline) that was output.
	#
	# These lines of text are interspersed in the order they were received,
	# to ensure the best possible match-up of errors to regular output.
	#
	# If the command returns a non-zero exit code, a
	# Giddyup::CommandWrapper::CommandFailed exception is raised containing
	# the status of the failed command and all output.
	#
	def self.run_command(cmd)
		output = []
		Open3.popen3(cmd) do |stdin, stdout, stderr, thr|
			# We don't want to talk *to* you
			stdin.close

			fds = [stdout, stderr]

			until fds.empty?
				a = IO.select(fds)

				if a[0].include? stdout
					if stdout.eof?
						stdout.close
						fds.delete(stdout)
					else
						output << [:stdout, stdout.readline.chomp]
					end
				end

				if a[0].include? stderr
					if stderr.eof?
						stderr.close
						fds.delete(stderr)
					else
						output << [:stderr, stderr.readline.chomp]
					end
				end
			end
		end

		if $?.exitstatus != 0
			raise CommandFailed.new($?, output)
		end

		output
	end

	# Run a command, but only return stdout as a string
	def self.run_command_stdout(cmd)
		run_command(cmd).
		  select { |l| l[0] == :stdout }.
		  map { |l| l[1] }.
		  join("\n")
	end
end
