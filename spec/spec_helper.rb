require "govuk_connect"
require "climate_control"

Dir["spec/support/*.rb"].each do |f|
  require_relative "support/#{File.basename(f)}"
end

RSpec.configure do |config|
  config.include SSHHelper

  config.before :each do
    allow(STDERR).to receive(:puts)
  end

  config.around :each do |example|
    ClimateControl.modify(USER: "test") { example.run }
  end
end
