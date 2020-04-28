RSpec.describe "ssh" do
  around(:each) do |example|
    ClimateControl.modify(USER: "test") { example.run }
  end

  it "supports SSHing to a given machine" do
    cli = GovukConnect::CLI.new
    allow(cli).to receive(:warn)
    status = double(:status, success?: true)

    allow(Open3).to receive(:capture2).with([
      "ssh",
      "-o",
      "ConnectTimeout=2",
      "test@jumpbox.integration.publishing.service.gov.uk",
      "govuk_node_list",
      "-c",
      "jumpbox",
    ].join(" ")).and_return([
      "foo",
      status,
    ])

    expect(cli).to receive(:exec).with(
      "ssh",
      "-J",
      "test@jumpbox.integration.publishing.service.gov.uk",
      "test@foo",
    )

    cli.main(["-e", "integration", "ssh", "jumpbox"])
  end
end
