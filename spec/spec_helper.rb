require "govuk_connect"
require "climate_control"

Dir["spec/support/*.rb"].each do |f|
  require_relative "support/#{File.basename(f)}"
end

RSpec.configure do |config|
  config.include SSHHelper

  config.before :each do
    disable_ssh_open3_capture2
  end

  config.around :each do |example|
    # suppress 'warn' messages printed by the CLI
    expect { example.run }.to output.to_stderr
  end

  config.around :each do |example|
    example.run
  rescue SystemExit => e
    raise "Unexpected call to exit: #{e.status}"
  end

  config.around :each do |example|
    ClimateControl.modify(USER: "test") { example.run }
  end
end
