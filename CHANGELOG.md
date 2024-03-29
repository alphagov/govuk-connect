## 0.8.1

* Update link to GOV.UK Kubernetes docs in output.

## 0.8.0

* govuk-connect will be retired in the near future, once the remaining govuk-puppet infrastructure has been decommissioned.
* The `app-console` and `app-dbconsole` commands, which have not worked since the move to Kubernetes, now print a message with the equivalent kubectl command.
* Drop support for Ruby 2.7.

# 0.7.1

* Improve error messaging when not using VPN ([#83](https://github.com/alphagov/govuk-connect/pull/83))

# 0.7.0

* Drop support for Ruby 2.6

# 0.6.0

* Fix YAML alias parsing error for Ruby 3.1 ([#69](https://github.com/alphagov/govuk-connect/pull/69))
* Drop support for Ruby 2.5

# 0.5.2

* Fix incorrect call to ssh_capture ([#62](https://github.com/alphagov/govuk-connect/pull/62))

# 0.5.1

* Fix dbconsole undefined local variable or method `name_and_number' ([#61](https://github.com/alphagov/govuk-connect/pull/61))

# 0.5.0

* Remove support for sidekiq-monitoring ([#54](https://github.com/alphagov/govuk-connect/pull/54))
* Remove carrenza CI and production ([#55](https://github.com/alphagov/govuk-connect/pull/55))

# 0.4.0

* Remove carrenza staging ([#51](https://github.com/alphagov/govuk-connect/pull/51))

# 0.3.3

* Improve the `--help` text to match what users run on a day-to-day basis ([#49](https://github.com/alphagov/govuk-connect/pull/49))

# 0.3.2 (0.3.1 release yanked)

* Stop sorting AWS nodes as it's done by `govuk_node_list` in GOV.UK Puppet ([#46](https://github.com/alphagov/govuk-connect/pull/46))

# 0.3.0

* Add `scp-push` and `scp-pull` command to copy files between machines ([#41](https://github.com/alphagov/govuk-connect/pull/41))

# 0.2.1

* Fix parsing of `--` arguments for SSH ([#39](https://github.com/alphagov/govuk-connect/pull/39))

# 0.2.0

* Add `test` as an available environment to SSH to ([#36](https://github.com/alphagov/govuk-connect/pull/36))

# 0.1.0

* Restructure code to support testing ([#10](https://github.com/alphagov/govuk-connect/pull/10), [#16](https://github.com/alphagov/govuk-connect/pull/16))

# 0.0.2

* Fix path to path to govuk directory

# 0.0.1

* Initial release with previous work from `govuk-guix`
