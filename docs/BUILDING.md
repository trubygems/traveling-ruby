# Building and releasing

You only need this to contribute to Traveling Ruby, reproduce a release, or build packages with your own Ruby versions or gems. To use the released packages, see [Using the packages](USING.md).

## What a release builds

Two files drive every build:

- [versions/VERSION.txt](../versions/VERSION.txt) is the release date, such as `20261102`. Packages are named after it and the release is tagged `rel-<date>`.
- [versions/RUBY_VERSIONS.txt](../versions/RUBY_VERSIONS.txt) lists the Ruby versions, one per line. The first one is the default for `cli.sh` and the GitHub Action.

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
| `linux`, `linux-musl` | Any machine with Docker | Builds inside the `you54f/traveling-ruby-builder-<arch>` images. See [linux/README.md](../linux/README.md). |
| `macos` | macOS with the Xcode command line tools | Builds a runtime of the libraries the gems need, then Ruby. Cross-building x86_64 on arm64 needs Rosetta. See [macos/README.md](../macos/README.md). |
| `windows` | Windows, with RubyInstaller and MSYS2 | Repackages a RubyInstaller build. [build-windows.yml](../.github/workflows/build-windows.yml) shows the steps. |
| `windows`, without native gems | macOS or Linux with 7-Zip | `cd windows && rake` downloads RubyInstaller and repacks it. CI tests these packages but never releases them. |

## The Docker images

The Linux builds run in `you54f/traveling-ruby-builder-x86_64` and `you54f/traveling-ruby-builder-arm64`, tagged with `IMAGE_VERSION` from the platform's `Rakefile`: `4.0.0-centos7` for `linux` and `4.0.0-alpine` for `linux-musl`. Build one locally with `rake image`.

To publish new images, change `IMAGE_VERSION`, then run the [images workflow](../.github/workflows/images.yml) from the Actions tab. It builds and pushes both architectures for the platform you choose.

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
| Manual run | The `platforms` input, such as `linux macos`. Tick `rebuild_runtime` to rebuild the macOS runtime even if the registry has it. |
| Release | All except the cross-built Windows packages |

Each platform has its own reusable workflow, called once per architecture: `build-linux.yml` (for `linux` and `linux-musl`), `build-macos.yml`, `build-windows.yml` and `build-windows-via-unix.yml`. Every Ruby version is a separate job. Changes to Markdown files and `docs/` don't trigger a build.

To run the setup step on your machine:

```bash
EVENT=workflow_dispatch PLATFORMS="linux macos" ./scripts/ci-setup.sh
```

## Releasing

1. Update `versions/VERSION.txt` to the release date and `versions/RUBY_VERSIONS.txt` to the Ruby versions, newest supported first.
2. Update the lockfiles in `shared/gemfiles` to the latest gem versions.
3. Update the versions in [README.md](../README.md) and the docs.
4. Open a pull request, check the builds, and merge it.
5. Publish a GitHub release tagged `rel-<date>`, matching `VERSION.txt`. The build fails at once if the tag doesn't match.

The release run builds every platform, then its `publish` job:

- uploads every package and native gem tarball to the release
- writes and uploads `SHA256SUMS`
- attests the build provenance of every file in `SHA256SUMS`

`publish` waits for every platform, so a failing build blocks the whole release rather than publishing part of it. Fix the build and re-run the failed jobs.
