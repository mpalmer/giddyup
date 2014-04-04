require 'spec_helper'

describe Giddyup::GitDeploy do
	let(:stdout)  { StringIO.new }
	let(:stderr)  { StringIO.new }
	let(:command) do
		cmd = double('command wrapper')
		allow(cmd).to receive(:run_command).and_return([])
		allow(cmd).to receive(:run_command_stdout).and_return("")
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

	it "tells me where I'm pushing to" do
		gd.run

		expect(stdout.string).to match(/Deploying to environment 'spec'/)
	end

	it "tells me that I'm pushing to an upstream" do
		allow(command).
		  to receive(:run_command_stdout).
		  with("git config -f /.git-deploy --get-all 'environment.spec.pushTo'").
		  and_return("git@git.example.com:repos/app.git")

		gd.run

		expect(stdout.string).to match(%r{Pushing HEAD to remote 'git@git.example.com:repos/app.git})
	end

	it "pushes to an upstream" do
		allow(command).
		  to receive(:run_command_stdout).
		  with("git config -f /.git-deploy --get-all 'environment.spec.pushTo'").
		  and_return("git@git.example.com:repos/app.git")
		expect(command).
		  to receive(:run_command).
		  with("git push 'git@git.example.com:repos/app.git' HEAD:master").
		  and_return([])

		gd.run
	end

	it "pushes to multiple upstreams" do
		allow(command).
		  to receive(:run_command_stdout).
		  with("git config -f /.git-deploy --get-all 'environment.spec.pushTo'").
		  and_return("git@git.example.com:repos/app.git legacy@oldserver.example.com:production/repo")
		expect(command).
		  to receive(:run_command).
		  with("git push 'git@git.example.com:repos/app.git' HEAD:master").
		  and_return([])
		expect(command).
		  to receive(:run_command).
		  with("git push 'legacy@oldserver.example.com:production/repo' HEAD:master").
		  and_return([])

		gd.run
	end
end
