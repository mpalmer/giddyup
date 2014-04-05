# Class implementing the git-deploy command line.
#
# Create an instance with an array of command line parameters, and call `#run`.
#

require 'open3'
require 'terminal-display-colors'
require 'giddyup/command_wrapper'

module Giddyup; end

class Giddyup::GitDeploy
	attr_reader :env, :verbose

	def initialize(argv, opts = {})
		argv = argv.dup
		@verbose = false

		if argv.index('-v')
			@verbose = true
			argv.delete('-v')
		end

		@stdout  = opts[:stdout] || $stdout
		@stderr  = opts[:stderr] || $stderr
		@command = opts[:command_wrapper] || Giddyup::CommandWrapper

		begin
			@base_dir = @command.run_command_stdout("git rev-parse --show-toplevel")
		rescue Giddyup::CommandWrapper::CommandFailed => e
			raise RuntimeError,
			      "ERROR: Not in a git tree"
		end

		@config_file = File.join(@base_dir, '.git-deploy')

		@env = argv.shift

		unless argv.empty?
			raise RuntimeError,
			      "Unknown config parameter(s): #{argv.inspect}"
		end

	end

	def run
		start_time = Time.now

		if @env.nil? or @env.empty?
			raise RuntimeError,
			      "No environment given to deploy to"
		end

		@stdout.puts "Deploying to environment '#{@env}'"

		do_push
		do_trigger

		@stdout.printf "Completed deployment in %.2f seconds.", (Time.now - start_time).to_f
	end

	private
	def do_push
		config_item("pushTo", true).each do |t|
			run_command "Pushing HEAD to remote '#{t}'",
			            "git push '#{t}' HEAD:master"
		end
	end

	def do_trigger
		targets.each do |t|
			ssh, dir = t.split(':', 2)
			run_command "Triggering deployment for '#{t}'",
			            "ssh #{ssh} /usr/local/lib/giddyup/trigger-deploy " +
			            "#{@verbose ? '-v ' : ''}#{dir}"
		end
	end

	# From a list of `target` / `target-enumerator` configuration parameters
	# (in the form returned from `config_list`), return a one-dimensional
	# array of strings containing the names of all machines to deploy to.
	#
	def targets
		@targets ||= enumerate_targets
	end

	def enumerate_targets
		config_list('target(Enumerator)?$').map do |li|
			if li[0].downcase == 'target'
				li[1]
			elsif li[0].downcase == 'targetenumerator'
				rv = run_command("Enumerating targets using '#{li[1]}'", li[1]).split(/\s+/)
				if $?.exitstatus != 0
					raise RuntimeError,
					      "Target enumeration failed.  Aborting."
				end
				rv
			else
				raise RuntimeError,
				      "Unknown target expansion option: #{li[0]}"
			end
		end.flatten
	end

	# Get the value(s) of a configuration item from the config file.
	#
	# Reads the `.git-deploy` config file, and retrieves the value of the
	# config `item`.  If you pass `true` to `multi`, then the configuration
	# parameter is read as a "multi-value" parameter, and the list of
	# configuration parameters is returned as an array; otherwise, we will
	# get a single value, returned as a string, and if multiple values are
	# returned, a RuntimeError will be raised.
	#
	def config_item(item, multi = false)
		cmd = "git config -f #{@config_file} " +
		      "#{multi ? '--get-all' : '--get'} " +
		      "'environment.#{@env}.#{item}'"

		begin
			s = @command.run_command_stdout(cmd)
		rescue Giddyup::CommandWrapper::CommandFailed => e
			if e.status.exitstatus == 2 and !multi
				raise RuntimeError,
				      "Multiple values found for a single-value parameter environment.#{@env}.#{item}"
			elsif e.status.exitstatus == 1
				# This means "nothing found", which we're cool with
				return multi ? [] : ""
			else
				raise RuntimeError,
				      "Failed to get config parameter environment.#{@env}.#{item}"
			end
		end

		if multi
			s.split(/\s+/)
		else
			s
		end
	end

	# Retrieve the in-order list of configuration parameters whose
	# item name matches the anchored `regex`.
	#
	# This function returns an array of the form `[[name, value], [name,
	# value], ...]`.
	#
	def config_list(regex)
		cmd = "git config -f #{@config_file} " +
		      "--get-regexp 'environment.#{@env}.#{regex}'"

		@command.
		  run_command_stdout(cmd).
		  split("\n").
		  map { |l| l.split(/\s+/, 2) }.
		  map { |item|	[item[0].gsub("environment.#{@env}.", ''), item[1]] }
	end

	# Run a command, with all sorts of prettyness.
	#
	# This function will run the specified command, telling the user what is
	# happening.  If the command succeeds (that is, exits with a status of
	# 0), then a green "OK" will be printed, otherwise a red "FAILED" will be
	# printed.  If the command fails, or @verbose is set, then the output of
	# the command will be displayed after the status line, with `stdout: ` or
	# `stderr: ` prefixed to each line, as appropriate.
	#
	# Regardless of what happens, the stdout of the command will be returned
	# as a string.
	#
	def run_command(desc, cmdline)
		@stdout.print "#{desc}..."

		output = nil
		failed = false
		begin
			output = @command.run_command(cmdline)
		rescue Giddyup::CommandWrapper::CommandFailed => e
			@stdout.puts " FAILED.".red
			output = e.output
			failed = true
		else
			@stdout.puts " OK.".green
		end

		if @verbose or failed
			@stdout.puts cmdline
			@stdout.puts output.map { |l| "#{l[0]}: #{l[1]}" }.join("\n")
		end

		return output.select { |l| l[0] == :stdout }.map { |l| l[1] }.join("\n")
	end
end
