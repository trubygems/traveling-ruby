# truby

**truby** packages Ruby apps with [Traveling Ruby](../README.md), a portable Ruby, so people can run them on Linux, macOS and Windows without installing Ruby. It ships in the `traveling-ruby` gem.

```console
$ gem install traveling-ruby
$ truby package
Packaging hello 1.0.0 with Ruby 3.4.12 (Traveling Ruby 3.4.12-0)
  ✓ linux-x86_64    12 gems, 2 native  pkg/hello-1.0.0-linux-x86_64.tar.gz    14.1 MB
  ✓ linux-arm64     12 gems, 2 native  pkg/hello-1.0.0-linux-arm64.tar.gz     13.8 MB
  ✓ macos-x86_64    12 gems, 2 native  pkg/hello-1.0.0-macos-x86_64.tar.gz    14.6 MB
  ✓ macos-arm64     12 gems, 2 native  pkg/hello-1.0.0-macos-arm64.tar.gz     14.4 MB
  ✓ windows-x86_64  12 gems, 2 native  pkg/hello-1.0.0-windows-x86_64.tar.gz  20.2 MB

Done in 9.8s. Launcher: hello
```

Each package holds a launcher per program, the app, and a Ruby with the app's locked gems installed:

```
hello-1.0.0-linux-x86_64/
  hello              launcher (hello.bat on Windows)
  lib/app/           the app
  lib/ruby/          Ruby and the app's gems
  lib/bundle/config  Bundler settings for the app
```

Nothing is compiled. Gems are installed from their `ruby` platform `.gem` files, and native gems get the extensions Traveling Ruby built for the release, so you can package for every platform from any machine. `traveling-ruby` also works as the command's name.

## Get started

```sh
bundle lock --add-platform ruby   # lock gems truby can install for every target
truby init                        # write truby.yml
truby check                       # see that every gem works on every target
truby package
```

`truby check` builds nothing. It shows each launcher and each native gem, and says what to do about a gem with no extension built for a target:

```
Gems
  ✓ 65 locked for the ruby platform
  ✓ json-3.1.0        built for all targets
  ✗ prism-2.1.0       no extension built for all targets
      → 3.4.12-0 builds prism 1.9.0: pin it with gem "prism", "1.9.0"

Not ready to package.
```

`truby package` stops on the same problem, since a gem without its extension fails when the app loads it. Pin a version the release builds, or pass `--allow-missing-extensions` to package without it.

## truby.yml

The app's packaging settings live in `truby.yml` (or `.truby.yml`), and command line options win over it:

```yaml
name: pact
version: 2.5.0
ruby: 3.4.12
targets: [linux-x86_64, linux-arm64, macos-arm64, windows-x86_64]
bin:
  pact-broker: pact-broker.rb   # a script in the app
  pact-mock-service:            # bin/, exe/, pact-mock-service.rb, or a gem's executable
ruby_opts: [-EUTF-8]
keep: [pact_broker/public]      # gem files that pruning would remove
```

| Setting | Option | Default |
| --- | --- | --- |
| `name` | `--name` | the app directory's name |
| `version` | `--app-version` | none; when set it goes in package names |
| `bin` | `--bin NAME[=SCRIPT]` | `bin/NAME` or `exe/NAME` |
| `targets` | `--targets` | `linux-x86_64, linux-arm64, macos-x86_64, macos-arm64, windows-x86_64` (`truby targets` lists them all) |
| `ruby` | `--ruby` | the latest release's Ruby |
| `revision` | `--revision` | the newest release of that Ruby |
| `runtime` | `--full` | `slim`; `full` adds Ruby's headers and static libraries |
| `without` | `--without` | `development, test` |
| `ruby_opts` | `--ruby-opt` | none; passed to `ruby` by each launcher |
| `keep` | `--keep` | none; a gem, or a path in one, that pruning keeps |
| `prune` | `--[no-]prune` | on: removes gems' tests, docs and extension sources |
| `archive` | `--[no-]archive` | on: a `.tar.gz` per package, and `SHA256SUMS` |
| `allow_missing_extensions` | `--allow-missing-extensions` | off |
| `source` | `--source` | `https://github.com/trubygems/traveling-ruby`, or a directory of release assets |
| `out` | `--out` | `pkg` |

A `bin` entry with no script runs the first of `bin/NAME`, `exe/NAME`, `NAME.rb` and `NAME` in the app, or else the `NAME` executable of a locked gem, so an app can ship `rackup` or `puma` without a script of its own.

Downloads are verified against each release's `SHA256SUMS` and the lockfile's `CHECKSUMS`, and cached in `~/.cache/traveling-ruby`. Pass `-v` to list each gem as it is installed.

## Package a gem

`truby gem` packages a gem from rubygems.org with a launcher for each of its executables:

```console
$ truby gem rubocop --targets macos-arm64,linux-x86_64
$ ./pkg/rubocop-1.92.2-macos-arm64/rubocop --version
1.92.2
```

Give a version as `rubocop:1.92.2`, and pick executables with `--bin`.

## Rake task

```ruby
# Rakefile
require "traveling_ruby/rake_task"

TravelingRuby::RakeTask.new do |t|
  t.app_version = "1.0.0"
end
```

`rake package` builds every target, `rake package:linux-arm64` builds one and `rake package:check` checks the app. The task reads `truby.yml`, and settings given to it win over the file.

## How a launcher runs the app

A launcher runs `lib/ruby/bin/ruby -rbundler/setup` with the program's script, with `BUNDLE_GEMFILE` pointing at the app's Gemfile and any `BUNDLE_PATH` from the user's environment cleared. It follows symlinks, to itself or to a directory above it, so you can link it onto the `PATH`.

The packaged lockfile locks only the `ruby` platform, with the checksums of the gems installed, so Bundler finds exactly what is in the package.

Gems from git sources are not supported yet. Gems from path sources must be inside the app, and ship with it.

## YJIT

`ruby_opts: [--yjit]` turns YJIT on in the launchers. Linux runtimes are built with YJIT from the release after 3.4.12-0 and 4.0.9-0, and macOS runtimes from the release after that. Windows runtimes are not yet, so there Ruby prints `warning: Ruby was built without YJIT support` and runs without it.

## Development

```sh
cd packager
bundle install
bundle exec rake test
bundle exec rake test:end_to_end   # package the fixture apps with a real release and run them
```

The end-to-end tests package real-world apps too: [the Pact CLI](test/fixtures/pact-cli), as pact-standalone ships it, and [a Pact Broker](test/fixtures/pact_broker) on SQLite or PostgreSQL under Puma, which the test publishes a pact to.

## Releasing

The gem is published by the [Packager workflow](../.github/workflows/packager.yml) with trusted publishing, so no rubygems.org API key is stored. Bump `TravelingRuby::VERSION`, merge, then tag the merge:

```sh
git tag gem-v0.1.0
git push origin gem-v0.1.0
```

The workflow tests the gem, checks the tag matches its version, and pushes it from the `rubygems` environment.
