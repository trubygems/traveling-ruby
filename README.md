# Traveling Ruby

Self-contained, portable Ruby binaries for Linux (glibc and musl), macOS and Windows, on x86_64 and arm64.

Bundle one with your Ruby app and ship a single package that runs without your users installing Ruby or any gems. A packaged app runs only the Ruby it ships with and never loads the user's own Ruby, gems or `RUBYLIB`.

## Platforms

Traveling Ruby builds Ruby 3.3.13, 3.4.12 and 4.0.9. Each Ruby version and target has its own release, such as [ruby-3.4.12-0-linux-x86_64](https://github.com/trubygems/traveling-ruby/releases/tag/ruby-3.4.12-0-linux-x86_64).

| Platform | Package name | Architectures | Runs on |
| --- | --- | --- | --- |
| Linux (glibc) | `linux` | x86_64, arm64 | glibc 2.17 or later (CentOS 7, Ubuntu 14.04, Debian 8 and newer) |
| Linux (musl) | `linux-musl` | x86_64, arm64 | musl 1.2.2 or later (Alpine 3.15 and newer) |
| macOS | `macos` | x86_64, arm64 | macOS 12.2 or later |
| Windows | `windows` | x86_64, arm64 | Windows 10 or later; arm64 needs Windows 11 and Ruby 3.4 or later |

On Alpine, Ruby itself needs nothing extra, but gems with C++ extensions need `libgcc_s`, which Alpine doesn't install by default. These are `charlock_holmes`, `eventmachine`, `mysql2` and `unf_ext`. Without it they fail to load with `Error loading shared library libgcc_s.so.1`. To use them, run `apk add libgcc`.

Releases are tagged `ruby-<ruby>-<revision>-<platform>-<arch>` and hold `traveling-ruby-<ruby>-<revision>-<platform>-<arch>.tar.gz`. The revision starts at 0 and goes up only when the runtime itself is rebuilt. The `-full` packages also contain the prebuilt native extension gems, which are published one gem per tarball as well. New gem versions are added to the existing release, and older ones are never removed. Every release has a `SHA256SUMS` file, a `manifest.json` listing its runtime and gems, and a build provenance attestation.

## Quickstart

```bash
curl -fsSL https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh | sh
~/.travelling-ruby/bin/ruby --version
```

On GitHub Actions:

```yml
- uses: trubygems/traveling-ruby@main
- run: ruby --version
```

## Documentation

- [Using the packages](docs/USING.md): downloading and verifying packages, the installer, the GitHub Action and the bundled gems.
- [Tutorial: packaging an app](docs/TUTORIAL.md): walks through the [examples repo](https://github.com/trubygems/traveling-ruby-examples), from a hello world script to a Rails app.
- [The packager gem](packager/README.md): packages an app and its locked gems for each platform in one command.
- [Reducing package size](docs/REDUCING_PACKAGE_SIZE.md)
- [Building and releasing](docs/BUILDING.md): building packages yourself, CI and cutting a release.

## History

This project is a fork of [phusion/traveling-ruby](https://github.com/phusion/traveling-ruby), which is no longer maintained. We maintain it for the [Pact](https://docs.pact.io) project, whose users run Ruby tools without installing Ruby. Pact now has replacement tooling in Rust, but we keep Traveling Ruby going, as automated as we can make it.

Thanks to Phusion and Hongli Lai for their work, and on behalf of the many Ruby developers who have shipped their apps with it.
