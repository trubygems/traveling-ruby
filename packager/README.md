# traveling-ruby gem

Packages a Ruby app with [Traveling Ruby](../README.md) runtimes, so users can run it without installing Ruby. One command builds a package per platform:

```
pkg/hello-linux-x86_64.tar.gz
pkg/hello-linux-arm64.tar.gz
pkg/hello-macos-x86_64.tar.gz
pkg/hello-macos-arm64.tar.gz
pkg/hello-windows-x86_64.tar.gz
pkg/SHA256SUMS
```

Each package holds a launcher, the app, and a runtime with the app's locked gems installed:

```
hello-linux-x86_64/
  hello              launcher (hello.bat on Windows)
  lib/app/           the app
  lib/ruby/          the runtime and its gems
  lib/bundle/config  Bundler settings for the app
```

Nothing is compiled. Gems are installed from their `ruby` platform `.gem` files, and gems with native extensions get the extensions built for the release, so you can package for every platform from any machine.

## Install

```sh
gem install traveling-ruby
```

## Package an app

The app needs an entry point, `bin/<name>` or `exe/<name>` by default, and, if it uses gems, a `Gemfile.lock`. Add the `ruby` platform to the lockfile first, so it locks gems the packager can install for every target:

```sh
bundle lock --add-platform ruby
traveling-ruby package
```

Run `traveling-ruby package --help` for every option. The common ones:

| Option | Default |
| --- | --- |
| `--targets LIST` | `linux-x86_64,linux-arm64,macos-x86_64,macos-arm64,windows-x86_64` (`traveling-ruby targets` lists them all) |
| `--ruby VERSION` | the latest release's Ruby |
| `--entry PATH` | `bin/NAME` or `exe/NAME` |
| `--name NAME` | the app directory's name |
| `--app-version VERSION` | none; when set it goes in package names |
| `--without GROUPS` | `development,test` |
| `--ruby-opt OPT` | none; passed to `ruby` by the launcher, repeatable |
| `--source URL_OR_DIR` | `https://github.com/trubygems/traveling-ruby`, or a directory of release assets |
| `--strict` | off |

Downloads are verified against each release's `SHA256SUMS` and the lockfile's `CHECKSUMS`, and cached in `~/.cache/traveling-ruby`.

## Rake task

```ruby
# Rakefile
require "traveling_ruby/rake_task"

TravelingRuby::RakeTask.new do |t|
  t.entry = "bin/hello"
  t.app_version = "1.0.0"
end
```

`rake package` builds every target and `rake package:linux-arm64` builds one. The task takes the same settings as the command line options.

## Native extensions

Each release builds a set of native gems (see the release's `manifest.json`). When the lockfile locks a native gem at a version the release did not build, the packager warns and names the versions it did build:

```
warning: bcrypt-3.1.20 has a native extension, but ruby-3.4.12-0-linux-arm64 builds bcrypt 3.1.22; pin one of those, e.g. gem "bcrypt", "3.1.22"
```

The package is still made, but that gem will not load in it. Pass `--strict` to fail instead.

Gems from git sources are not supported yet. Gems from path sources must be inside the app, and ship with it.

## How the launcher runs the app

The launcher runs `lib/ruby/bin/ruby -rbundler/setup lib/app/<entry>` with `BUNDLE_GEMFILE` pointing at the app's Gemfile, and with any `BUNDLE_PATH` from the user's environment cleared. It follows symlinks, so you can link it onto the `PATH`.

The packaged lockfile is rewritten to lock only the `ruby` platform, with the checksums of the gems that were installed, so Bundler finds exactly what is in the package.

## YJIT

`--ruby-opt --yjit` turns YJIT on in the launcher. The runtimes are not built with YJIT yet, so for now Ruby prints `warning: Ruby was built without YJIT support` and runs without it.

## Development

```sh
cd packager
bundle install
bundle exec rake test
```
