# GOV.UK Connect

This is a command line tool to help you connect to GOV.UK's infrastructure e.g.

```bash
govuk-connect ssh -e integration frontend
```

## Installation

### With Homebrew on macOS or Linux:

```bash
brew tap alphagov/gds # This will exist if you use the gds-cli
brew install govuk-connect
```

### With RubyGems:

```bash
sudo gem install govuk-connect
```

> If you use a Ruby version manager like [rbenv](https://github.com/rbenv/rbenv), you may find this only installs `govuk-connect` for a particular version of Ruby. Try installing outside of an rbenv-managed directory to fix this e.g. your home directory.

## Usage

If you have the gds-cli installed (you [should do](https://docs.publishing.service.gov.uk/manual/access-aws-console.html)!), you can use this tool within it. This means you only have to use one tool to do AWS and SSH.

```
gds govuk connect --help
```

It can be shortened to `gds govuk c`.

Whichever installation method you choose, you can use the above method or the standalone `govuk-connect` binary.

