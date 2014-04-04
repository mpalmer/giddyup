require 'spec_helper'

describe Giddyup::GitDeploy do
	let(:stdout)  { StringIO.new }
	let(:stderr)  { StringIO.new }
	let(:command) do
		cmd = double('command wrapper')
		allow(cmd).to receive(:run_command).and_return([])
		allow(cmd).to receive(:run_command_stdout).and_return("")
		allow(cmd).
		  to receive(:run_command_stdout).
		  with("git config -f /.git-deploy --get-regexp 'environment.spec.target(Enumerator)?$'").
		  and_return("environment.spec.target app@db1a.example.com:/home/app/production\n" +
		             "environment.spec.target app@db1b.example.com:/home/app/production\n")
		cmd
	end
	let(:gd)      { Giddyup::GitDeploy.new(
	                                     ['spec'],
	                                     :stdout          => stdout,
	                                     :stderr          => stderr,
	                                     :command_wrapper => command
	                                   )
	             }

	before :each do
		stdout.string = ""
		stderr.string = ""
	end

	it "tells me that I'm triggering a deployment" do
		gd.run

		expect(stdout.string).
		  to match(
		       %r{Triggering deployment for 'app@db1a.example.com:/home/app/production'}
		     )
		expect(stdout.string).
		  to match(
		       %r{Triggering deployment for 'app@db1b.example.com:/home/app/production'}
		     )
	end

	it "runs the triggering commands" do
		expect(command).
		  to receive(:run_command).
		  with("ssh app@db1a.example.com /usr/local/lib/giddyup/trigger-deploy /home/app/production").
		  and_return([])
		expect(command).
		  to receive(:run_command).
		  with("ssh app@db1b.example.com /usr/local/lib/giddyup/trigger-deploy /home/app/production").
		  and_return([])

		gd.run
	end
end
