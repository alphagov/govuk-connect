RSpec.describe "ssh" do
  let(:cli) { GovukConnect::CLI.new }

  before { disable_any_exec(cli) }

  it "supports SSHing to a class of machines" do
    stub_govuk_node_list(machine_class: "jumpbox",
                         hostnames: %w(foo),
                         environment: :integration)

    args = ssh_command(environment: :integration,
                       hostname: "foo")

    allow(cli).to receive(:exec).with(*args)
    cli.main(["-e", "integration", "ssh", "jumpbox"])
    expect(cli).to have_received(:exec)
  end
end
