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
		attr_reader :status, :output, :command

		def initialize(status, output, command)
			@status  = status
			@output  = output
			@command = command
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
	# If a block is passed, it will be called for each line of output, and
	# pass two arguments: `<stream>` and `<line>`.
	#
	def self.run_command(cmd)
		output = []
		rv = nil

		Open3.popen3(cmd) do |stdin, stdout, stderr, thr|
			# We don't want to talk *to* you
			stdin.close

			fds = [stdout, stderr]

			until fds.empty?
				a = IO.select(fds, [], [], 0.1)

				if a.nil?
					if fds == [stderr]
						# SSH is an annoying sack of crap.  When using ControlMaster
						# (multiplexing), the background mux process keeps stderr open,
						# which means that this loop never ends (because stderr.eof?
						# is never true).  So, we're using the heuristic that if stdout
						# is closed (ie it hsa been removed from `fds`) and we've timed
						# out rather than seeing any further activity on stderr) then
						# the command execution is done.
						break
					else
						# We had a timeout, but we're still running!
						next
					end
				end

				if a[0].include? stdout
					if stdout.eof?
						stdout.close
						fds.delete(stdout)
					else
						l = stdout.readline.chomp
						yield :stdout, l if block_given?
						output << [:stdout, l]
					end
				end

				if a[0].include? stderr
					if stderr.eof?
						stderr.close
						fds.delete(stderr)
					else
						l = stderr.readline.chomp
						yield :stderr, l if block_given?
						output << [:stderr, l]
					end
				end
			end

			rv = thr.value
		end

		if rv.exitstatus != 0
			raise CommandFailed.new(rv, output, cmd)
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
