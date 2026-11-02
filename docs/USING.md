# Using the packages

## Downloading a package

Download a package for your platform from the [releases page](https://github.com/trubygems/traveling-ruby/releases) and unpack it:

```bash
mkdir -p ~/.travelling-ruby
curl -fsSL https://github.com/trubygems/traveling-ruby/releases/download/ruby-3.4.12-0-linux-x86_64/traveling-ruby-3.4.12-0-linux-x86_64.tar.gz | tar -xz -C ~/.travelling-ruby
~/.travelling-ruby/bin/ruby --version
```

Packages are named `traveling-ruby-<ruby>-<revision>-<platform>-<arch>.tar.gz`, and each Ruby version, revision and target has its own release, tagged `ruby-<ruby>-<revision>-<platform>-<arch>`:

- `<revision>` starts at 0 and goes up only when the runtime is rebuilt, for example for new build dependencies. [versions/RUBY_REVISIONS.txt](../versions/RUBY_REVISIONS.txt) has the current revision of each Ruby version.
- `<platform>` is `linux`, `linux-musl`, `macos` or `windows`.
- `<arch>` is `x86_64` or `arm64`.

Each package comes in two flavours:

- The plain package has Ruby, its standard library and its default gems.
- The `-full` package also has every native extension gem that Traveling Ruby builds, listed in [shared/gemfiles](../shared/gemfiles).

Each native extension gem is also published on its own, as `traveling-ruby-gems-<ruby>-<revision>-<platform>-<arch>-<gem>-<version>.tar.gz`, in the same release. New gem versions are added to the release as they are built, and old ones stay, so a pinned version keeps working. Unpack one into your app's bundle directory (`vendor/ruby`) to add just that gem. The [tutorial](TUTORIAL.md) shows how.

The executables in `bin/` are wrapper scripts, `.bat` files on Windows. They point `RUBYLIB`, `GEM_HOME` and `GEM_PATH` at the package itself, so it never loads gems or libraries from a Ruby that is already installed. Child processes get the original environment back.

## Verifying a download

Every release has a `SHA256SUMS` file, and a `manifest.json` that lists the runtime and each gem with its version and checksum:

```bash
curl -fsSLO https://github.com/trubygems/traveling-ruby/releases/download/ruby-3.4.12-0-linux-x86_64/SHA256SUMS
sha256sum --check --ignore-missing SHA256SUMS
```

On macOS, use `shasum -a 256 --check --ignore-missing SHA256SUMS`.

Each release asset also has a [build provenance attestation](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations), which proves it was built by this repository's release workflow. Check it with the GitHub CLI:

```bash
gh attestation verify traveling-ruby-3.4.12-0-linux-x86_64.tar.gz --repo trubygems/traveling-ruby
```

## The installer

`cli.sh` detects your platform and installs a package to `~/.travelling-ruby`. Without options, it installs the newest Ruby version at its current revision.

```console
$ curl -fsSL https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh | sh -s -- --help
Usage: sh [-v <version>] [-r <revision>] [--set-path] [--clean-install] [--ci]

  -v <version>          Ruby version to install (default: the newest)
  -r <revision>         Revision of the traveling ruby package to download (default: the current one)
  --set-path            Add the traveling ruby bin path to the PATH environment variable (default: false)
  --clean-install       Remove any existing traveling ruby installation before installing (default: false)
  --ci                  Set --set-path to true and --clean-install to true (default: false)
  -g                    list of gems to install
```

For example, to install revision 0 of Ruby 3.3.13:

```bash
curl -fsSL https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh | sh -s -- -v 3.3.13 -r 0
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
          ruby-version: 3.4.12     # optional, defaults to the newest Ruby version
          revision: 0              # optional, defaults to the version's current revision
          gems: rack-3.1.8 rainbow # optional, name-version installs a fixed version
      - run: ruby --version
        shell: pwsh
```

On Windows, call `ruby.bat` from bash. `cmd`, `powershell` and `pwsh` find `ruby` on their own.

## Docker

[docker/Dockerfile](../docker/Dockerfile) installs a package into an Ubuntu image. Pick the Ruby version and revision with build arguments:

```bash
docker build --build-arg TRAVELING_RUBY_VERSION=3.4.12 --build-arg TRAVELING_RUBY_REVISION=0 -t traveling-ruby docker
docker run --rm traveling-ruby ruby --version
```
