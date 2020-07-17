module SCPHelper
  def scp_push_command(environment:,
                       hostname:,
                       sources:,
                       destination:,
                       provider: :aws,
                       additional_arguments: [])
    jumpbox = GovukConnect::CLI::JUMPBOXES.dig(environment, provider)
    [
      "scp",
      "-o",
      "ProxyJump=test@#{jumpbox}",
      "-o",
      "User=test",
      *additional_arguments,
      "--",
      *sources,
      "#{hostname}:#{destination}",
    ]
  end

  def scp_pull_command(environment:,
                       hostname:,
                       sources:,
                       destination:,
                       provider: :aws,
                       additional_arguments: [])
    jumpbox = GovukConnect::CLI::JUMPBOXES.dig(environment, provider)
    [
      "scp",
      "-o",
      "ProxyJump=test@#{jumpbox}",
      "-o",
      "User=test",
      *additional_arguments,
      "--",
      *sources.map { |source| "#{hostname}:#{source}" },
      destination,
    ]
  end
end
