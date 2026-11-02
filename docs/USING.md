# Using the packages

## Downloading a package

Download a package for your platform from the [releases page](https://github.com/trubygems/traveling-ruby/releases) and unpack it:

```bash
mkdir -p ~/.travelling-ruby
curl -fsSL https://github.com/trubygems/traveling-ruby/releases/download/rel-20261102/traveling-ruby-20261102-3.4.12-linux-x86_64.tar.gz | tar -xz -C ~/.travelling-ruby
~/.travelling-ruby/bin/ruby --version
```

Packages are named `traveling-ruby-<release>-<ruby>-<platform>-<arch>.tar.gz`:

- `<release>` is the release date, and the release tag is `rel-<release>`.
- `<platform>` is `linux`, `linux-musl`, `macos` or `windows`.
- `<arch>` is `x86_64` or `arm64`.

Each package comes in two flavours:

- The plain package has Ruby, its standard library and its default gems.
- The `-full` package also has every native extension gem that Traveling Ruby builds, listed in [shared/gemfiles](../shared/gemfiles).

Each native extension gem is also published on its own, as `traveling-ruby-gems-<release>-<ruby>-<platform>-<arch>-<gem>-<version>.tar.gz`. Unpack one into your app's bundle directory (`vendor/ruby`) to add just that gem. The [tutorial](TUTORIAL.md) shows how.

The executables in `bin/` are wrapper scripts, `.bat` files on Windows. They point `RUBYLIB`, `GEM_HOME` and `GEM_PATH` at the package itself, so it never loads gems or libraries from a Ruby that is already installed. Child processes get the original environment back.

## Verifying a download

Every release has a `SHA256SUMS` file:

```bash
curl -fsSLO https://github.com/trubygems/traveling-ruby/releases/download/rel-20261102/SHA256SUMS
sha256sum --check --ignore-missing SHA256SUMS
```

On macOS, use `shasum -a 256 --check --ignore-missing SHA256SUMS`.

Each release asset also has a [build provenance attestation](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations), which proves it was built by this repository's release workflow. Check it with the GitHub CLI:

```bash
gh attestation verify traveling-ruby-20261102-3.4.12-linux-x86_64.tar.gz --repo trubygems/traveling-ruby
```

## The installer

`cli.sh` detects your platform and installs a package to `~/.travelling-ruby`. Without options, it installs the latest release and the first Ruby version that release lists.

```console
$ curl -fsSL https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh | sh -s -- --help
Usage: sh [-v <version>] [-d <release-date>] [--set-path] [--clean-install] [--ci]

  -v <version>          Ruby version to install (default: the first version built by the release)
  -d <release-date>     Release date of the traveling ruby package to download (default: latest)
  --set-path            Add the traveling ruby bin path to the PATH environment variable (default: false)
  --clean-install       Remove any existing traveling ruby installation before installing (default: false)
  --ci                  Set --set-path to true and --clean-install to true (default: false)
  -g                    list of gems to install
```

For example, to install Ruby 3.3.13 from the 20261102 release:

```bash
curl -fsSL https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh | sh -s -- -d 20261102 -v 3.3.13
```

`--set-path` adds the Ruby bin directory to `GITHUB_PATH` on GitHub Actions and to `CIRRUS_ENV` on Cirrus CI. Elsewhere it prints the `PATH` line to add yourself.

## GitHub Actions

```yml
on:
  workflow_dispatch:
  push:

jobs:
  traveling_ruby:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
      fail-fast: false
    runs-on: ${{ matrix.os }}
    steps:
      - uses: trubygems/traveling-ruby@main
        with:
          ruby-version: 3.4.12     # optional, defaults to the release's first Ruby version
          release: 20261102        # optional, defaults to the latest release
          gems: rack-3.1.8 rainbow # optional, name-version installs a fixed version
      - run: ruby --version
        shell: pwsh
```

On Windows, call `ruby.bat` from bash. `cmd`, `powershell` and `pwsh` find `ruby` on their own.

## Docker

[docker/Dockerfile](../docker/Dockerfile) installs a package into an Ubuntu image. Pick the release and Ruby version with build arguments:

```bash
docker build --build-arg TRAVELING_RUBY_PKG_DATE=20261102 --build-arg TRAVELING_RUBY_VERSION=3.4.12 -t traveling-ruby docker
docker run --rm traveling-ruby ruby --version
```
