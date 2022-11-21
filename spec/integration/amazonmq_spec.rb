RSpec.describe "amazonmq" do
  include SocketHelper
  let(:cli) { GovukConnect::CLI.new }
  before { disable_any_exec(cli) }

  it "opens an remote port forward to publishingmq.(environment).govuk-internal.digital:443" do
    stub_socket_port_free(32_768)
    jumpbox = GovukConnect::CLI::JUMPBOXES.dig(:integration, :aws)

    args = [
      "ssh",
      "-N",
      "-L",
      "32768:publishingmq.integration.govuk-internal.digital:443",
      "test@#{jumpbox}",
    ]

    allow(cli).to receive(:exec).with(*args)
    cli.main(["-e", "integration", "amazonmq"])
  end
end
