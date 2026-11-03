# Building and releasing

You only need this to contribute to Traveling Ruby, reproduce a release, or build packages with your own Ruby versions or gems. To use the released packages, see [Using the packages](USING.md).

## What a release builds

Two files drive every build:

- [versions/RUBY_VERSIONS.txt](../versions/RUBY_VERSIONS.txt) lists the Ruby versions, one per line.
- [versions/RUBY_REVISIONS.txt](../versions/RUBY_REVISIONS.txt) gives each Ruby version its revision, such as `3.4.12 0`. Packages are named `traveling-ruby-<ruby>-<revision>-<platform>-<arch>` and published to a release tagged `ruby-<ruby>-<revision>-<platform>-<arch>`. A version missing from the file has revision 0.

The native extension gems, and the versions they are pinned to, come from the Gemfiles and lockfiles in [shared/gemfiles](../shared/gemfiles). Every platform builds the same versions.

Each platform directory has a `Rakefile`. Set `RUBY_VERSIONS` and `ARCHITECTURES` to build fewer versions or architectures than the files list:

```bash
cd linux
RUBY_VERSIONS=3.4.12 ARCHITECTURES=arm64 rake
```

`rake -T` lists the tasks. The main ones are `rake` (build and package), `rake package_full` (package with the native gems included) and `rake test`.

## Building locally

| Platform | Builds on | Notes |
| --- | --- | --- |
| `linux`, `linux-musl` | Any machine with Docker | Builds inside the `ghcr.io/trubygems/traveling-ruby-builder-<arch>` images. See [linux/README.md](../linux/README.md). |
| `macos` | macOS with the Xcode command line tools | Builds a runtime of the libraries the gems need, then Ruby. Cross-building x86_64 on arm64 needs Rosetta. See [macos/README.md](../macos/README.md). |
| `windows` | Windows, with RubyInstaller and MSYS2 | Repackages a RubyInstaller build. [build-windows.yml](../.github/workflows/build-windows.yml) shows the steps. |
| `windows`, without native gems | macOS or Linux with 7-Zip | `cd windows && rake` downloads RubyInstaller and repacks it. CI tests these packages but never releases them. |

## The Docker images

The Linux builds run in `ghcr.io/trubygems/traveling-ruby-builder-x86_64` and `ghcr.io/trubygems/traveling-ruby-builder-arm64`, built from `image/`. Their tags are `centos7-<hash>` for `linux` and `alpine-<hash>` for `linux-musl`, where `<hash>` is the git tree hash of `image/`, so any change there gives a new tag and each commit keeps using the image it was built with. `scripts/builder-image.sh name` prints the tag for a checkout. `rake image` builds it locally, unless it is published.

CI pushes the images when their tag is not published yet, from pushes and from pull requests in this repository. Pull requests from forks build them into the Actions cache instead.

## The macOS runtime

The macOS builds need a runtime of the libraries the gems link against, which takes a long time to build. [runtime-macos.yml](../.github/workflows/runtime-macos.yml) builds it once per architecture and pushes it to a container registry as an OCI artifact, and every macOS build pulls it from there. Branches, pull requests and releases all share it.

[scripts/macos-runtime.sh](../scripts/macos-runtime.sh) tags the runtime `macos-<arch>-xcode<major>-<hash>`, where the hash covers the scripts and patches that build it. Changing one of them, or the runner moving to a new major Xcode version, gives a new tag, and the next build builds and pushes it. Ruby and the gems are built on top of the runtime in each build, so they are not part of the tag.

- The runtimes are stored in `ghcr.io/<owner>/<repo>-runtime`. Set the `MACOS_RUNTIME_REPO` repository variable to use another registry, such as a Gitea instance.
- GitHub creates the package as private the first time it is pushed. Make it public in the package settings if forks should be able to pull it.
- Pull requests from forks can't push to the registry. When the runtime they need isn't there, they build it and pass it to their build jobs as a workflow artifact.
- Run the workflow from the Actions tab to build a runtime ahead of a release, or tick `rebuild` to replace one.

To use the script on your machine, install [oras](https://oras.land) and log in to the registry:

```bash
ARCHITECTURES=arm64 ./scripts/macos-runtime.sh tag
ARCHITECTURES=arm64 RUNTIME_REPO=ghcr.io/trubygems/traveling-ruby-runtime ./scripts/macos-runtime.sh pull
```

`pull` unpacks the runtime into `macos/runtime`, so `rake` in `macos` skips building it. Set `ORAS_OPTS=--plain-http` for a local registry without TLS.

## CI

[build.yml](../.github/workflows/build.yml) builds and tests every platform. Its `setup` job, [scripts/ci-setup.sh](../scripts/ci-setup.sh), reads the versions files and picks the platforms to build:

| Event | Platforms built |
| --- | --- |
| Push to `main` | All |
| Pull request | All, or only those named by `build:<platform>` labels, such as `build:linux` and `build:macos` |
| Manual run | The `platforms` input, such as `linux macos`, and the `ruby_versions` input, such as `3.4.12`. Tick `rebuild_runtime` to rebuild the macOS runtime even if the registry has it, and `publish` to publish what it builds. |

Each platform has its own reusable workflow, called once per architecture: `build-linux.yml` (for `linux` and `linux-musl`), `build-macos.yml`, `build-windows.yml` and `build-windows-via-unix.yml`. Every Ruby version is a separate job. Changes to Markdown files and `docs/` don't trigger a build.

To run the setup step on your machine:

```bash
EVENT=workflow_dispatch PLATFORMS="linux macos" ./scripts/ci-setup.sh
```

## Releasing

Every push to `main` publishes, as does a manual run with `publish` ticked. The `publish` job waits for every platform, so a failing build publishes nothing; fix it and re-run the failed jobs. It then runs [scripts/publish-releases.sh](../scripts/publish-releases.sh), which for each runtime it built:

- creates the release `ruby-<ruby>-<revision>-<platform>-<arch>` if it doesn't exist yet, marking the newest Ruby's `linux-x86_64` release as the latest
- uploads only the packages and gem tarballs the release doesn't already have, so published files never change
- rewrites the release's `SHA256SUMS` and `manifest.json` to cover everything in it
- attests the build provenance of everything it built

GitHub allows 1000 assets per release. The script refuses to take a release past 950 and fails the job, which is the cue to bump the revision.

### New gem versions

Update the lockfiles in `shared/gemfiles` and merge. The build reuses the existing runtimes' revisions, and publishing adds the new gem tarballs to each release next to the old ones. The `-full` package of a release stays as first published; it has the gem versions of that day.

To publish one Ruby version without waiting for a merge, run the build workflow by hand with `ruby_versions` set and `publish` ticked.

### A new Ruby version

Add it to `versions/RUBY_VERSIONS.txt`, newest first, and to `versions/RUBY_REVISIONS.txt` at revision 0. Update the versions in [README.md](../README.md) and the docs, open a pull request, check the builds, and merge it.

### Rebuilding a runtime

When a runtime has to change for a Ruby version that is already published, for example for new build dependencies or a fix to the packaging, bump its revision in `versions/RUBY_REVISIONS.txt`. The next publish creates new releases for that revision, with every gem rebuilt. The old revision's releases stay as they are.
