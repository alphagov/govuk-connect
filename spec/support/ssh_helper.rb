module SSHHelper
  def stub_govuk_node_list(machine_class:,
                           hostnames:,
                           environment:,
                           provider: :aws)
    jumpbox = GovukConnect::CLI::JUMPBOXES.dig(environment, provider)
    status = double(:status, success?: true)

    allow(Open3).to receive(:capture2).with([
      "ssh",
      "-o",
      "ConnectTimeout=2",
      "test@#{jumpbox}",
      "govuk_node_list",
      "-c",
      machine_class,
    ].join(" ")).and_return([
      hostnames.join("\n"),
      status,
    ])
  end

  def ssh_command(environment:, hostname:, provider: :aws)
    jumpbox = GovukConnect::CLI::JUMPBOXES.dig(environment, provider)
    ["ssh", "-J", "test@#{jumpbox}", "test@#{hostname}"]
  end
end
