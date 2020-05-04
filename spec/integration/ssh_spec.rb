RSpec.describe "ssh" do
  let(:cli) { GovukConnect::CLI.new }

  before { disable_any_exec(cli) }

  it "supports SSHing to a class of machines" do
    stub_govuk_node_list(machine_class: "jumpbox",
                         hostnames: %w[foo],
                         environment: :integration)

    args = ssh_command(environment: :integration,
                       hostname: "foo")

    allow(cli).to receive(:exec).with(*args)
    cli.main(["-e", "integration", "ssh", "jumpbox"])
    expect(cli).to have_received(:exec)
  end

  it "supports SSHing to a particular machine" do
    args = ssh_command(environment: :integration,
                       hostname: "hostname.internal")

    allow(cli).to receive(:exec).with(*args)
    cli.main(["-e", "integration", "ssh", "hostname.internal"])
    expect(cli).to have_received(:exec)
  end

  it "supports SSHing to a specific provider" do
    stub_govuk_node_list(machine_class: "jumpbox",
                         hostnames: %w[foo],
                         environment: :production,
                         provider: :carrenza)

    args = ssh_command(environment: :production,
                       hostname: "foo",
                       provider: :carrenza)

    allow(cli).to receive(:exec).with(*args)
    cli.main(["-e", "production", "ssh", "carrenza/jumpbox"])
    expect(cli).to have_received(:exec)
  end

  it "supports SSHing to a numbered machine" do
    stub_govuk_node_list(machine_class: "jumpbox",
                         hostnames: %w[foo1 foo2],
                         environment: :integration)

    args = ssh_command(environment: :integration,
                       hostname: "foo2")

    allow(cli).to receive(:exec).with(*args)
    cli.main(["-e", "integration", "ssh", "jumpbox:2"])
    expect(cli).to have_received(:exec)
  end
end
