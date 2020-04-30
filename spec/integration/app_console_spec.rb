RSpec.describe "app-(db)console" do
  let(:cli) { GovukConnect::CLI.new }

  before do
    disable_any_exec(cli)
    disable_yaml_load_file
  end

  it "SSHs and then runs govuk_app_console" do
    node_classes = { "backend" => { "apps" => %w(my-app) } }

    stub_puppet_hieradata(environment: :integration,
                          node_classes: node_classes)

    stub_govuk_node_list(machine_class: "backend",
                         hostnames: %w(foo),
                         environment: :integration)

    args = ssh_command(environment: :integration,
                       hostname: "foo",
                       suffix: ["-t", "govuk_app_console my-app"])

    allow(cli).to receive(:exec).with(*args)
    cli.main(["-e", "integration", "app-console", "my-app"])
    expect(cli).to have_received(:exec)
  end

  it "SSHs and then runs govuk_app_dbconsole" do
    node_classes = { "backend" => { "apps" => %w(my-app) } }

    stub_puppet_hieradata(environment: :integration,
                          node_classes: node_classes)

    stub_govuk_node_list(machine_class: "backend",
                         hostnames: %w(foo),
                         environment: :integration)

    args = ssh_command(environment: :integration,
                       hostname: "foo",
                       suffix: ["-t", "govuk_app_dbconsole my-app"])

    allow(cli).to receive(:exec).with(*args)
    cli.main(["-e", "integration", "app-dbconsole", "my-app"])
    expect(cli).to have_received(:exec)
  end

  def stub_puppet_hieradata(environment:, node_classes:)
    base_path = "/home/user/govuk/govuk-puppet/hieradata_aws"
    file_path = "#{base_path}/#{environment}.yaml"

    allow(YAML).to receive(:load_file).with(file_path)
      .and_return("node_class" => node_classes)
  end

  def disable_yaml_load_file
    allow(YAML).to receive(:load_file) do |*args|
      raise "Unexpected call to YAML: #{args}"
    end
  end
end
