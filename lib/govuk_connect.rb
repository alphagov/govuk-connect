require 'govuk_connect/cli'

module GovukConnect
  def self.main(argv)
    CLI.new.main(argv)
  end
end
