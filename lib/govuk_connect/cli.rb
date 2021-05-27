require "uri"
require "yaml"
require "open3"
require "socket"
require "timeout"
require "optparse"
require "govuk_connect/version"

class GovukConnect::CLI
  def self.bold(string)
    "\e[1m#{string}\e[0m"
  end

  def bold(string)
    self.class.bold(string)
  end

  USAGE_BANNER = "Usage: gds govuk connect TYPE TARGET [options]".freeze

  EXAMPLES = <<-EXAMPLES.freeze
    gds govuk connect ssh --environment integration backend

    gds govuk connect scp-push --environment integration backend filename.txt /tmp/

    gds govuk connect scp-pull --environment integration backend /tmp/filename.txt ~/Downloads/

    gds govuk connect app-console --environment staging publishing-api

    gds govuk connect app-dbconsole -e integration whitehall_backend/whitehall

    gds govuk connect rabbitmq -e staging aws/rabbitmq
  EXAMPLES

  MACHINE_TARGET_DESCRIPTION = <<-DOCS.freeze
    The ssh, scp-*, rabbitmq connection types target machines.

    The machine can be specified by name, for example:

      gds govuk connect ssh -e integration #{bold('backend')}

    If the hosting provider is ambiguous, you'll need to specify it prior
    to the name, for example:

      gds govuk connect ssh -e staging #{bold('aws/')}backend

    If you want to connect to a specific machine, you can specify a number
    after the name, for example:

      gds govuk connect ssh -e integration backend#{bold(':2')}
  DOCS

  APP_TARGET_DESCRIPTION = <<-DOCS.freeze
    The app-console and app-dbconsole connection types target
    applications.

    The application is specified by name, for example:

      gds govuk connect app-console -e integration #{bold('publishing-api')}

    If the node class is ambiguous, you'll need to specify it prior to
    the name, for example:

      gds govuk connect app-console -e integration #{bold('whitehall_backend/')}whitehall

    If you want to connect to a specific machine, you can specify a
    number after the name, for example:

      gds govuk connect app-console -e integration publishing-api#{bold(':2')}
  DOCS

  CONNECTION_TYPE_DESCRIPTIONS = {
    "ssh" => "Connect to a machine through SSH.",
    "app-console" => "Launch a console for an application.  For example, a rails console when connecting to a Rails application.",
    "app-dbconsole" => "Launch a console for the database for an application.",
    "rabbitmq" => "Setup port forwarding to the RabbitMQ admin interface.",
  }.freeze

  RABBITMQ_PORT = 15_672

  JUMPBOXES = {
    test: {
      aws: "jumpbox.pink.test.govuk.digital",
    },
    integration: {
      aws: "jumpbox.integration.publishing.service.gov.uk",
    },
    staging: {
      aws: "jumpbox.staging.govuk.digital",
    },
    production: {
      aws: "jumpbox.production.govuk.digital",
    },
  }.freeze

  def log(message)
    warn message if @verbose
  end

  def print_empty_line
    warn ""
  end

  def info(message)
    warn message
  end

  def error(message)
    warn "\e[1m\e[31m#{message}\e[0m"
  end

  def print_ssh_username_configuration_help
    info "The SSH username used was: #{bold(ssh_username)}"
    info "Check this is correct, and if it isn't, set the `USER` environment variable to the correct username."
  end

  # From Rosetta Code: https://rosettacode.org/wiki/Levenshtein_distance#Ruby
  def levenshtein_distance(string1, string2)
    string1 = string1.downcase
    string2 = string2.downcase
    costs = Array(0..string2.length) # i == 0
    (1..string1.length).each do |i|
      costs[0] = i
      nw = i - 1 # j == 0; nw is lev(i-1, j)
      (1..string2.length).each do |j|
        costs[j] = [
          costs[j] + 1,
          costs[j - 1] + 1,
          string1[i - 1] == string2[j - 1] ? nw : nw + 1,
        ].min
        nw = costs[j]
      end
    end
    costs[string2.length]
  end

  def strings_similar_to(target, strings)
    strings.select do |s|
      levenshtein_distance(s, target) <= 3 # No specific reasoning for this value
    end
  end

  def check_ruby_version_greater_than(required_major:, required_minor:)
    major, minor = RUBY_VERSION.split "."

    insufficient_version = (
      major.to_i < required_major || (
        major.to_i == required_major &&
        minor.to_i < required_minor
      )
    )

    if insufficient_version
      error "insufficient Ruby version: #{RUBY_VERSION}"
      error "must be at least #{required_major}.#{required_minor}"

      exit 1
    end
  end

  def port_free?(port)
    # No idea how well this works, but it's hopefully better than nothing

    log "debug: checking if port #{port} is free"
    Socket.tcp("127.0.0.1", port, connect_timeout: 0.1) {}
    false
  rescue Errno::ETIMEDOUT
    log "debug: port #{port} doesn't seem to be free"
    false
  rescue Errno::ECONNREFUSED
    log "debug: port #{port} is free"
    true
  end

  def random_free_port
    tries = 0

    while tries <= 10
      port = rand(32_768...61_000)

      return port if port_free? port

      tries += 1
    end

    raise "couldn't find open port"
  end

  def hosting_providers
    JUMPBOXES
      .map { |_env, jumpboxes| jumpboxes.keys }
      .flatten
      .uniq
  end

  def jumpbox_for_environment_and_hosting(environment, hosting)
    raise "missing environment" unless environment
    raise "missing hosting" unless hosting

    jumpbox = JUMPBOXES[environment][hosting]

    unless jumpbox
      error "error: couldn't determine jumpbox for #{hosting}/#{environment}"
      exit 1
    end

    jumpbox
  end

  def single_hosting_provider_for_environment(environment)
    jumpboxes = JUMPBOXES[environment]

    if jumpboxes.size == 1
      jumpboxes.keys[0]
    else
      false
    end
  end

  def config_file
    @config_file ||= begin
      directory = ENV.fetch("XDG_CONFIG_HOME", "#{Dir.home}/.config")

      File.join(directory, "config.yaml")
    end
  end

  def ssh_username
    @ssh_username ||= begin
      if File.exist? config_file
        config_ssh_username = YAML.load_file(config_file)["ssh_username"]
      end

      config_ssh_username || ENV["USER"]
    end
  end

  def ssh_identity_file
    @ssh_identity_file ||= begin
      YAML.load_file(config_file)["ssh_identity_file"] if File.exist? config_file
    end
  end

  def ssh_identity_arguments
    if ssh_identity_file
      ["-i", ssh_identity_file]
    else
      []
    end
  end

  def user_at_host(user, host)
    "#{user}@#{host}"
  end

  def govuk_node_list_classes(environment, hosting)
    log "debug: looking up classes in #{hosting}/#{environment}"
    classes = ssh_capture("govuk_node_list --classes").sort

    log "debug: classes:"
    classes.each { |c| log " - #{c}" }

    classes
  end

  def get_domains_for_node_class(target, environment, hosting)
    domains = ssh_capture(environment, hosting, "govuk_node_list -c #{target}")
    if hosting == :aws
      domains
    else
      domains.sort
    end
  end

  def ssh_capture(environment, hosting, remote_command)
    command = [
      "ssh",
      "-o",
      "ConnectTimeout=2", # Show a failure quickly
      *ssh_identity_arguments,
      user_at_host(
        ssh_username,
        jumpbox_for_environment_and_hosting(environment, hosting),
      ),
      remote_command,
    ].join(" ")

    log "debug: running command: #{command}"
    output, status = Open3.capture2(command)

    unless status.success?
      error "\nerror: command failed: #{command}"
      print_empty_line
      print_ssh_username_configuration_help
      exit 1
    end

    output.split("\n")
  end

  def govuk_directory
    File.join(ENV["HOME"], "govuk")
  end

  def govuk_puppet_node_class_data(environment, hosting)
    log "debug: fetching govuk-puppet node class data for #{hosting} #{environment}"

    local_hieradata_root = File.join(
      govuk_directory,
      "govuk-puppet",
      {
        aws: "hieradata_aws",
      }[hosting],
    )

    hieradata_file = File.join(local_hieradata_root, "#{environment}.yaml")
    log "debug: reading #{hieradata_file}"

    environment_specific_hieradata = YAML.load_file(hieradata_file)

    if environment_specific_hieradata["node_class"]
      environment_specific_hieradata["node_class"]
    else
      common_hieradata = YAML.load_file(
        File.join(local_hieradata_root, "common.yaml"),
      )

      common_hieradata["node_class"]
    end
  end

  def node_classes_for_environment_and_hosting(environment, hosting)
    govuk_puppet_node_class_data(
      environment,
      hosting,
    ).map do |node_class, _data|
      node_class
    end
  end

  def application_names_from_node_class_data(environment, hosting)
    node_class_data = govuk_puppet_node_class_data(
      environment,
      hosting,
    )

    all_names = node_class_data.flat_map do |_node_class, data|
      data["apps"]
    end

    all_names.sort.uniq
  end

  def node_class_for_app(app_name, environment, hosting)
    log "debug: finding node class for #{app_name} in #{hosting} #{environment}"

    node_class_data = govuk_puppet_node_class_data(
      environment,
      hosting,
    )

    app_lookup_hash = {}
    node_class_data.each do |node_class, data|
      data["apps"].each do |app|
        if app_lookup_hash.key? app
          app_lookup_hash[app] += [node_class]
        else
          app_lookup_hash[app] = [node_class]
        end
      end
    end

    node_classes = app_lookup_hash[app_name]

    return if node_classes.nil?

    if node_classes.length > 1
      error "error: ambiguous node class for #{app_name} in #{environment}"
      print_empty_line
      info "specify the node class and application mame, for example: "
      node_classes.each do |node_class|
        info "\n  gds govuk connect app-console -e #{environment} #{node_class}/#{app_name}"
      end
      print_empty_line

      exit 1
    else
      node_class = node_classes.first
    end

    log "debug: node class: #{node_class}"

    node_class
  end

  def hosting_for_target_and_environment(target, environment)
    hosting = single_hosting_provider_for_environment(
      environment,
    )

    unless hosting
      hosting, name, _number = parse_hosting_name_and_number(target)

      hosting ||= hosting_for_node_type(name, environment)
    end

    hosting
  end

  def hosting_for_node_type(node_type, environment)
    log "debug: Looking up hosting for node_type: #{node_type}"
    hosting = single_hosting_provider_for_environment(environment)

    return hosting if hosting

    aws_node_types = govuk_node_list_classes(environment, :aws)

    if aws_node_types.include?(node_type)
      :aws
    else
      error "error: couldn't find #{node_type} in #{environment}"

      similar_node_types = strings_similar_to(node_type, aws_node_types)

      if similar_node_types.any?
        info "\ndid you mean:"
        similar_node_types.each { |s| info " - #{s}" }
      else
        info "\nall node types:"
        all_node_types.each { |s| info " - #{s}" }
      end

      exit 1
    end
  end

  def hosting_for_app(app_name, environment)
    log "debug: finding hosting for #{app_name} in #{environment}"

    hosting = single_hosting_provider_for_environment(environment)

    if hosting
      log "debug: this environment has a single hosting provider: #{hosting}"
      return hosting
    end

    aws_app_names = application_names_from_node_class_data(
      environment,
      :aws,
    )

    if aws_app_names.include? app_name
      log "debug: #{app_name} is hosted in AWS"

      return :aws
    end

    error "error: unknown hosting value '#{hosting}' for #{app_name}"
    exit 1
  end

  def govuk_app_command(target, environment, command)
    node_class, app_name, number = parse_node_class_app_name_and_number(target)

    info "Connecting to the app #{command} for #{bold(app_name)},\
   in the #{bold(environment)} environment"

    hosting = hosting_for_app(app_name, environment)

    info "The relevant hosting provider is #{bold(hosting)}"

    node_class ||= node_class_for_app(
      app_name,
      environment,
      hosting,
    )

    unless node_class
      error "error: application '#{app_name}' not found."
      print_empty_line

      application_names = application_names_from_node_class_data(
        environment,
        hosting,
      )

      similar_application_names = strings_similar_to(app_name, application_names)
      if similar_application_names.any?
        info "did you mean:"
        similar_application_names.each { |s| info " - #{s}" }
      else
        info "all applications:"
        print_empty_line
        info "  #{application_names.join(', ')}"
        print_empty_line
      end

      exit 1
    end

    info "The relevant node class is #{bold(node_class)}"

    ssh(
      {
        hosting: hosting,
        name: node_class,
        number: number,
      },
      environment,
      command: "govuk_app_#{command} #{app_name}",
    )
  end

  def ssh(
    target,
    environment,
    command: false,
    port_forward: false,
    additional_arguments: []
  )
    log "debug: ssh to #{target} in #{environment}"

    target, hosting = ssh_target(target, environment)

    ssh_command = [
      "ssh",
      *ssh_identity_arguments,
      "-J",
      user_at_host(
        ssh_username,
        jumpbox_for_environment_and_hosting(environment, hosting),
      ),
      user_at_host(
        ssh_username,
        target,
      ),
    ]

    if command
      ssh_command += [
        "-t", # Force tty allocation so that interactive commands work
        command,
      ]
    elsif port_forward
      localhost_port = random_free_port

      ssh_command += [
        "-N",
        "-L",
        "#{localhost_port}:127.0.0.1:#{port_forward}",
      ]

      info "Port forwarding setup, access:\n\n  http://127.0.0.1:#{localhost_port}/\n\n"
    end

    ssh_command += additional_arguments

    info "\n#{bold('Running command:')} #{ssh_command.join(' ')}\n\n"

    exec(*ssh_command)
  end

  def scp(
    target,
    environment,
    files,
    push: false,
    additional_arguments: []
  )
    log "debug: scp #{push ? 'push' : 'pull'} to #{target} in #{environment}"

    target, hosting = ssh_target(target, environment)

    sources = files[0, files.length - 1]
    destination = files[-1]

    if push
      destination = "#{target}:#{destination}"
    else
      sources = sources.map { |source| "#{target}:#{source}" }
    end

    scp_command = [
      "scp",
      *ssh_identity_arguments,
      "-o",
      "ProxyJump=#{user_at_host(ssh_username, jumpbox_for_environment_and_hosting(environment, hosting))}",
      "-o",
      "User=#{ssh_username}",
      *additional_arguments,
      "--",
      *sources,
      destination,
    ]

    info "\n#{bold('Running command:')} #{scp_command.join(' ')}\n\n"

    exec(*scp_command)
  end

  def rabbitmq_root_password_command(hosting, environment)
    hieradata_directory = {
      aws: "puppet_aws",
    }[hosting]

    directory = File.join(
      govuk_directory,
      "govuk-secrets",
      hieradata_directory,
    )

    "cd #{directory} && rake eyaml:decrypt_value[#{environment},govuk_rabbitmq::root_password]"
  end

  def hosting_and_environment_from_url(url)
    uri = URI(url)

    host_to_hosting_and_environment = {
      "alert.integration.publishing.service.gov.uk" => %i[aws integration],
      "alert.staging.govuk.digital" => %i[aws staging],
      "alert.blue.staging.govuk.digital" => %i[aws staging],
      "alert.production.govuk.digital" => %i[aws production],
      "alert.blue.production.govuk.digital" => %i[aws production],
    }

    unless host_to_hosting_and_environment.key? uri.host
      error "error: unknown hosting and environment for: #{uri.host}"
      exit 1
    end

    host_to_hosting_and_environment[uri.host]
  end

  def parse_options(argv)
    options = {}
    @option_parser = OptionParser.new do |opts|
      opts.banner = USAGE_BANNER

      opts.on(
        "-e",
        "--environment ENVIRONMENT",
        "Select which environment to connect to",
      ) do |o|
        options[:environment] = o.to_sym
      end
      opts.on(
        "--hosting-and-environment-from-alert-url URL",
        "Select which environment to connect to based on the URL provided.",
      ) do |o|
        hosting, environment = hosting_and_environment_from_url(o)
        options[:hosting] = hosting
        options[:environment] = environment
      end
      opts.on("-p", "--port-forward SERVICE", "Connect to a remote port") do |o|
        options[:port_forward] = o
      end
      opts.on("-v", "--verbose", "Enable more detailed logging") do
        @verbose = true
      end

      opts.on("-h", "--help", "Prints usage examples and information") do
        info opts
        print_empty_line
        info bold("EXAMPLES")
        info EXAMPLES
        print_empty_line
        info bold("CONNECTION TYPES")
        types.keys.each do |x|
          info "  #{x}"
          description = CONNECTION_TYPE_DESCRIPTIONS[x]
          info "    #{description}" if description
        end
        print_empty_line
        info bold("MACHINE TARGET")
        info MACHINE_TARGET_DESCRIPTION
        print_empty_line
        info bold("APPLICATION TARGET")
        info APP_TARGET_DESCRIPTION
        exit
      end
      opts.on("-V", "--version", "Prints version information") do
        info GovukConnect::VERSION.to_s
        exit
      end
    end

    @option_parser.parse!(argv)

    options
  end

  def parse_hosting_name_and_number(target)
    log "debug: parsing target: #{target}"
    if target.is_a? Hash
      return %i[hosting name number].map do |key|
        target[key]
      end
    end

    if target.include? "/"
      hosting, name_and_number = target.split "/"

      hosting = hosting.to_sym

      unless %i[aws].include? hosting
        error "error: unknown hosting provider: #{hosting}"
        print_empty_line
        info "available hosting providers are:"
        hosting_providers.each { |x| info " - #{x}" }

        exit 1
      end
    else
      name_and_number = target
    end

    if name_and_number.include? ":"
      name, number = name_and_number.split ":"

      number = number.to_i
    else
      name = name_and_number
    end

    log "debug: hosting: #{hosting.inspect}, name: #{name.inspect}, number: #{number.inspect}"

    [hosting, name, number]
  end

  def parse_node_class_app_name_and_number(target)
    log "debug: parsing target: #{target}"
    if target.is_a? Hash
      return %i[node_class app_name number].map do |key|
        target[key]
      end
    end

    if target.include? "/"
      node_class, app_name_and_number = target.split "/"
    else
      app_name_and_number = target
    end

    if app_name_and_number.include? ":"
      app_name, number = app_name_and_number.split ":"

      number = number.to_i
    else
      app_name = app_name_and_number
    end

    log "debug: node_class: #{node_class.inspect}, app_name: #{app_name.inspect}, number: #{number.inspect}"

    [node_class, app_name, number]
  end

  def target_from_options(target, options)
    if options.key? :hosting
      hosting, name, number = parse_hosting_name_and_number(target)
      if hosting
        error "error: hosting specified twice"
        exit 1
      end

      {
        hosting: options[:hosting],
        name: name,
        number: number,
      }
    else
      target
    end
  end

  def ssh_target(target, environment)
    # Split something like aws/backend:2 in to :aws, 'backend', 2
    hosting, name, number = parse_hosting_name_and_number(target)

    if name.end_with? ".internal"
      target = name
      hosting = :aws
    else
      # The hosting might not have been provided, so check if necessary
      hosting ||= hosting_for_target_and_environment(target, environment)

      domains = get_domains_for_node_class(
        name,
        environment,
        hosting,
      )

      if domains.length.zero?
        error "error: couldn't find #{name} in #{hosting}/#{environment}"

        node_types = govuk_node_list_classes(environment, hosting)

        similar_node_types = strings_similar_to(name, node_types)

        if similar_node_types.any?
          info "\ndid you mean:"
          similar_node_types.each { |s| info " - #{s}" }
        else
          info "\nall node types:"
          node_types.each { |s| info " - #{s}" }
        end

        exit 1
      elsif domains.length == 1
        target = domains.first

        info "There is #{bold('one machine')} to connect to"
      else
        n_machines = bold("#{domains.length} machines")
        info "There are #{n_machines} of this class"

        if number
          unless number.positive?
            print_empty_line
            error "error: invalid machine number '#{number}', it must be > 0"
            exit 1
          end

          unless number <= domains.length
            print_empty_line
            error "error: cannot connect to machine number: #{number}"
            exit 1
          end

          target = domains[number - 1]
          info "Connecting to number #{number}"
        else
          target = domains.sample
          info "Connecting to a random machine (number #{domains.find_index(target) + 1})"
        end
      end
    end

    [target, hosting]
  end

  def check_for_target(target)
    unless target
      error "error: you must specify the target\n"
      warn USAGE_BANNER
      print_empty_line
      warn EXAMPLES
      exit 1
    end
  end

  def check_for_additional_arguments(command, args)
    unless args.empty?
      error "error: #{command} doesn't support arguments: #{args}"
      exit 1
    end
  end

  def types
    @types ||= {
      "app-console" => proc do |target, environment, args, extra_args, _options|
        check_for_target(target)
        check_for_additional_arguments("app-console", args)
        check_for_additional_arguments("app-console", extra_args)
        govuk_app_command(target, environment, "console")
      end,

      "app-dbconsole" => proc do |target, environment, args, extra_args, _options|
        check_for_target(target)
        check_for_additional_arguments("app-dbconsole", args)
        check_for_additional_arguments("app-dbconsole", extra_args)
        govuk_app_command(target, environment, "dbconsole")
      end,

      "rabbitmq" => proc do |target, environment, args, extra_args, _options|
        check_for_additional_arguments("rabbitmq", args)
        check_for_additional_arguments("rabbitmq", extra_args)

        target ||= "rabbitmq"

        root_password_command = rabbitmq_root_password_command(
          hosting_for_target_and_environment(target, environment),
          environment,
        )

        info "You'll need to login as the RabbitMQ #{bold('root')} user."
        info "Get the password from govuk-secrets, or example:\n\n"
        info "  #{bold(root_password_command)}"
        print_empty_line

        ssh(
          target,
          environment,
          port_forward: RABBITMQ_PORT,
        )
      end,

      "ssh" => proc do |target, environment, args, extra_args, options|
        check_for_target(target)
        target = target_from_options(target, options)

        ssh(
          target,
          environment,
          port_forward: options[:port_forward],
          additional_arguments: [args, extra_args].flatten,
        )
      end,

      "scp-pull" => proc do |target, environment, args, extra_args, options|
        check_for_target(target)
        target = target_from_options(target, options)

        if args.length < 2
          error "error: need at least two filenames"
          exit 1
        end

        scp(
          target,
          environment,
          args,
          additional_arguments: extra_args,
        )
      end,

      "scp-push" => proc do |target, environment, args, extra_args, options|
        check_for_target(target)
        target = target_from_options(target, options)

        if args.length < 2
          error "error: need at least two filenames"
          exit 1
        end

        scp(
          target,
          environment,
          args,
          push: true,
          additional_arguments: extra_args,
        )
      end,
    }
  end

  def main(argv)
    check_ruby_version_greater_than(required_major: 2, required_minor: 0)

    extra_arguments_after_double_dash = []

    double_dash_index = argv.index "--"
    if double_dash_index
      # This is used in the case of passing extra options to ssh and
      # scp, the -- acts as a separator, so to avoid optparse
      # interpreting those as options, split argv around -- before
      # parsing the options
      extra_arguments_after_double_dash = argv[double_dash_index + 1, argv.length]
      argv = argv[0, double_dash_index]
    end

    govuk_connect_options = parse_options(argv)
    type, target, *extra_arguments_before_double_dash = argv

    unless type
      error "error: you must specify the connection type\n"

      warn @option_parser.help

      warn "\nValid connection types are:\n"
      types.keys.each do |x|
        warn " - #{x}"
      end
      print_empty_line
      warn "Example commands:"
      warn EXAMPLES

      exit 1
    end

    handler = types[type]

    unless handler
      error "error: unknown connection type: #{type}\n"

      warn "Valid connection types are:\n"
      types.keys.each do |x|
        warn " - #{x}"
      end
      print_empty_line
      warn "Example commands:"
      warn EXAMPLES

      exit 1
    end

    environment = govuk_connect_options[:environment]&.to_sym

    unless environment
      error "error: you must specify the environment\n"
      warn @option_parser.help
      exit 1
    end

    unless JUMPBOXES.key? environment
      error "error: unknown environment '#{environment}'"
      print_empty_line
      info "Valid environments are:"
      JUMPBOXES.keys.each { |e| info " - #{e}" }
      exit 1
    end

    handler.call(
      target,
      environment,
      extra_arguments_before_double_dash,
      extra_arguments_after_double_dash,
      govuk_connect_options,
    )
  rescue Interrupt
    # Handle SIGTERM without printing a stacktrace
    exit 1
  end
end
