RSpec.describe "sidekiq-monitoring" do
  include SocketHelper

  let(:cli) { GovukConnect::CLI.new }

  before { disable_any_exec(cli) }

  it "opens an SSH tunnel to Sidekiq" do
    stub_socket_port_free(32768)

    stub_govuk_node_list(machine_class: "backend",
                         hostnames: %w[foo],
                         environment: :integration)

    args = ssh_command(environment: :integration,
                       hostname: "foo",
                       suffix: %w[-N -L 32768:127.0.0.1:3211])

    allow(cli).to receive(:exec).with(*args)
    cli.main(["-e", "integration", "sidekiq-monitoring"])
    expect(cli).to have_received(:exec)
  end
end
