# Tutorial: packaging an app

This tutorial packages Ruby apps for every platform Traveling Ruby supports, using the [traveling-ruby-examples](https://github.com/trubygems/traveling-ruby-examples) repo. Each example builds on the one before it:

| Example | What it shows |
| --- | --- |
| [hello](https://github.com/trubygems/traveling-ruby-examples/tree/main/examples/hello) | A script with no gem dependencies |
| [gem](https://github.com/trubygems/traveling-ruby-examples/tree/main/examples/gem) | An app with a pure Ruby gem (faker) |
| [native](https://github.com/trubygems/traveling-ruby-examples/tree/main/examples/native) | An app with a native extension gem (sqlite3) |
| [pact_broker](https://github.com/trubygems/traveling-ruby-examples/tree/main/examples/pact_broker) | A Rack app with many native gems |
| [rails](https://github.com/trubygems/traveling-ruby-examples/tree/main/examples/rails) | A Rails app |

You can build packages for every platform from Linux or macOS. Building on Windows is not supported, but the Windows packages it produces run there. The examples repo's [CI workflow](https://github.com/trubygems/traveling-ruby-examples/blob/main/.github/workflows/package.yml) builds each example and tests the packages on Linux, macOS and Windows.

```bash
git clone https://github.com/trubygems/traveling-ruby-examples
cd traveling-ruby-examples
```

## 1. A script with no dependencies

`examples/hello` has three parts:

```
hello
├── Rakefile
├── hello.rb
└── packaging
    ├── wrapper.bat
    └── wrapper.sh
```

### Choosing a Ruby

The top of the `Rakefile` names the Traveling Ruby package to use, as `<ruby version>-<revision>`:

```ruby
TRAVELING_RUBY_VERSION = "3.4.12-0"
```

The [README](../README.md#platforms) lists the Ruby versions Traveling Ruby builds, [versions/RUBY_REVISIONS.txt](../versions/RUBY_REVISIONS.txt) their current revisions, and the [releases page](https://github.com/trubygems/traveling-ruby/releases) every release.

### Packaging

```bash
cd examples/hello
rake package
```

For each platform, `rake package` downloads the matching Traveling Ruby package and builds `pkg/hello-1.0.0-<platform>-<arch>.tar.gz`, containing:

```
hello-1.0.0-linux-x86_64
├── hello              the wrapper script (hello.bat on Windows)
└── lib
    ├── app
    │   └── hello.rb   your app
    └── ruby           the unpacked Traveling Ruby package
```

To build one platform, run its task, for example `rake package:linux-x86_64`. `rake -T` lists them all. Set `DIR_ONLY=1` to leave the package as a directory instead of a tarball, which is quicker when you are trying things out.

### The wrapper script

Your users run the wrapper, not Ruby. It finds the directory it lives in, even through symlinks, and runs your app with the bundled Ruby:

```sh
exec "$LIBDIR/ruby/bin/ruby" "$LIBDIR/app/hello.rb" "$@"
```

`wrapper.bat` does the same on Windows, through `lib\ruby\bin\ruby.bat`.

### Testing a package

From the root of the examples repo, unpack the package for the machine you are on and run it:

```bash
APP_NAME=hello ./script/unpack-and-test.sh
```

## 2. Adding a gem

`examples/gem` adds [faker](https://rubygems.org/gems/faker). Its gems are listed in `packaging/Gemfile`, separate from the gems you need to build the package.

Gems are installed with your own Ruby, so the Ruby you run `rake` with must have the same major and minor version as the package. The `bundle_install` task stops if it doesn't.

```bash
cd examples/gem
bundle install
bundle exec rake package
```

`bundle_install` installs the gems into `build/vendor` with `BUNDLE_DEPLOYMENT`, then deletes anything compiled for your machine. `create_package` copies `build/vendor` into the package as `lib/vendor`, with the Gemfile, the lockfile and `packaging/bundler-config` as `lib/vendor/.bundle/config`:

```yaml
BUNDLE_PATH: .
BUNDLE_WITHOUT: development
BUNDLE_DISABLE_SHARED_GEMS: '1'
```

The wrapper now points Bundler at that Gemfile and loads `bundler/setup` before the app:

```sh
export BUNDLE_GEMFILE="$LIBDIR/vendor/Gemfile"
unset BUNDLE_IGNORE_CONFIG
unset RUBYGEMS_GEMDEPS
unset BUNDLE_APP_CONFIG
export BUNDLE_FROZEN=1

exec "$LIBDIR/ruby/bin/ruby" -E UTF-8 -rbundler/setup -I "$LIBDIR/app/lib" "$LIBDIR/app/gem.rb" "$@"
```

### The lockfile

`packaging/Gemfile.lock` is shared by every platform, so:

1. Its `PLATFORMS` section lists every platform you ship, for example `ruby`, `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `arm64-darwin`, `x64-mingw-ucrt` and `aarch64-mingw-ucrt`. Add them with `bundle lock --add-platform`.
2. Gems are locked to their plain `ruby` platform. Replace platform-specific entries such as `ffi (1.17.2-x86_64-linux-gnu)` with a single `ffi (1.17.2)`.

## 3. Adding a native extension

A native extension has to be compiled for each platform, which you can't do from one machine. Traveling Ruby builds the common ones for you, and each release publishes them one gem per tarball.

`examples/native` uses sqlite3. Its `Rakefile` lists the native gems and their versions:

```ruby
NATIVE_GEM_VERSIONS = {
  sqlite3: '2.8.0',
}
```

For each platform, `download_and_unpack_ext` downloads `traveling-ruby-gems-<ruby>-<revision>-<platform>-<arch>-sqlite3-2.8.0.tar.gz` and unpacks it into `lib/vendor/ruby`, over the gem source that Bundler installed.

The versions must be ones Traveling Ruby has built. The current ones are pinned in [shared/gemfiles](../shared/gemfiles), and every version built so far is listed in the release's `manifest.json`:

```bash
curl -fsSL https://github.com/trubygems/traveling-ruby/releases/download/ruby-3.4.12-0-linux-x86_64/manifest.json | jq -r '.gems[] | "\(.name) \(.version)"'
```

Lock the same versions in `packaging/Gemfile.lock`. If you need a gem that Traveling Ruby doesn't build, add it to the Gemfile in `shared/gemfiles` in a fork, and [build the packages yourself](BUILDING.md).

## 4. A Rack app

`examples/pact_broker` packages a Rack app with a dozen native gems, including nokogiri, pg, mysql2 and puma. It works like `native`, with one addition: nokogiri publishes precompiled gems for Windows, and Bundler on Windows picks those over the `ruby` platform gem. The `create_package` task rewrites the Windows lockfile to name that platform explicitly, so `BUNDLE_FROZEN` doesn't fail.

## 5. A Rails app

`examples/rails` packages a Rails app. The wrapper changes to the app directory and runs the `rails` executable from the bundled Ruby, so your users run Rails commands through it:

```sh
cd "$LIBDIR/app"
exec "$LIBDIR/ruby/bin/ruby" -E UTF-8 -rbundler/setup -I "$LIBDIR/app/lib" "$LIBDIR/ruby/bin.real/rails" "$@"
```

```bash
./rails server
```

## Next steps

- [Reduce the size of your packages](REDUCING_PACKAGE_SIZE.md) by removing tests, docs and other files your app doesn't need.
- [Verify the Traveling Ruby packages](USING.md#verifying-a-download) your build downloads.
