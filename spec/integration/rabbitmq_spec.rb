RSpec.describe "rabbitmq" do
  include SocketHelper

  let(:cli) { GovukConnect::CLI.new }

  before { disable_any_exec(cli) }

  it "opens an SSH tunnel to RabbitMQ" do
    stub_socket_port_free(32768)

    stub_govuk_node_list(machine_class: "rabbitmq",
                         hostnames: %w(foo),
                         environment: :integration)

    args = ssh_command(environment: :integration,
                       hostname: "foo",
                       suffix: %w(-N -L 32768:127.0.0.1:15672))

    allow(cli).to receive(:exec).with(*args)
    cli.main(["-e", "integration", "rabbitmq"])
    expect(cli).to have_received(:exec)
  end
end
