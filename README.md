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

> Note: If you previously installed `govuk-connect` via RubyGems, but
> switched to using Homebrew, you may have to do the following to get
> it to work:
>
> ```
> sudo gem uninstall govuk-connect
> rbenv rehash
> ```

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

## Releases

When you've merged the PR that bumps the version, publish a release tag and the gem to RubyGems from the `master` branch:

```bash
gem build govuk-connect
gem publish govuk-connect-<version>.gem # Credentials are in govuk-secrets/pass under packages/rubygems
git tag <version> # eg 0.0.3
git push origin <version>
```

To raise a PR to bump the Homebrew formula version, run:

`brew bump-formula-pr govuk-connect --url=https://rubygems.org/downloads/govuk-connect-<version>.gem --no-fork`

> If you have problems with this, note that the password Git asks for
> to push the changes to GitHub is in fact a [Personal Access
> Token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line).
> If you get in a real mess, run `brew update-reset`, and try `brew
> bump-formula-pr` again. If you really can't do it, [consider
> reopening a previous PR on this
> topic](https://github.com/alphagov/govuk-connect/pull/21).

