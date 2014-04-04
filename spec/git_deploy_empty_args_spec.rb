require 'giddyup/git_deploy'

describe Giddyup::GitDeploy do
	let(:gd) { Giddyup::GitDeploy.new([]) }

	it "Produces an error when given no args" do
		expect { gd.run }.
		  to raise_error(
		       RuntimeError,
		       "No environment given to deploy to"
		     )
	end
end
