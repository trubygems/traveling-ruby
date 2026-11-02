#!/bin/sh
# Stores the macOS runtime (macos/runtime) as an OCI artifact in a registry, so
# every branch, pull request and release reuses one build of it.
#
# Usage: macos-runtime.sh tag|exists|push|pull
#
#   tag     print the runtime's tag: macos-<arch>-xcode<major>-<inputs hash>
#   exists  exit 0 if the registry has that tag
#   push    pack macos/runtime and push it
#   pull    pull it and unpack it to macos/runtime
#
# Inputs (environment):
#   ARCHITECTURES  x86_64 or arm64
#   RUNTIME_REPO   repository to store runtimes in, e.g. ghcr.io/trubygems/traveling-ruby-runtime
#   ORAS_OPTS      extra oras options, e.g. --plain-http for a local registry
#
# The tag changes whenever a script that builds the runtime changes, or the
# runner moves to a new major Xcode version. Ruby and the gems are not inputs:
# they are built on top of the runtime in each build.

set -e

SELFDIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SELFDIR/.." && pwd)
MEDIA_TYPE=application/vnd.traveling-ruby.runtime.tar+gzip
INPUTS="macos/setup-runtime.sh macos/internal/bin macos/internal/reset_environment.sh
macos/internal/check_requirements.sh macos/internal/*.patch shared/library.sh"

runtime_tag() {
  : "${ARCHITECTURES:?set ARCHITECTURES to x86_64 or arm64}"
  xcode=$(xcodebuild -version | awk 'NR == 1 { split($2, v, "."); print v[1] }')
  # shellcheck disable=SC2086 # INPUTS is a list of globs
  hash=$(cd "$ROOT" && find $INPUTS -type f | LC_ALL=C sort | xargs shasum -a 256 | shasum -a 256 | cut -c1-16)
  echo "macos-$ARCHITECTURES-xcode$xcode-$hash"
}

ref() {
  : "${RUNTIME_REPO:?set RUNTIME_REPO to the repository to store runtimes in}"
  echo "$RUNTIME_REPO:$(runtime_tag)"
}

case "$1" in
  tag)
    runtime_tag
    ;;
  exists)
    oras manifest fetch $ORAS_OPTS "$(ref)" > /dev/null 2>&1
    ;;
  push)
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    # ccache only holds the runtime's own objects, and the Ruby sources are
    # downloaded per build, so neither is worth storing
    tar -C "$ROOT/macos" -czf "$tmp/runtime.tar.gz" \
      --exclude 'runtime/ccache/*' --exclude 'runtime/ruby-*.tar.gz' runtime
    ls -lh "$tmp/runtime.tar.gz"
    (cd "$tmp" && oras push $ORAS_OPTS --artifact-type application/vnd.traveling-ruby.runtime "$(ref)" "runtime.tar.gz:$MEDIA_TYPE" \
      --annotation "org.opencontainers.image.source=${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-trubygems/traveling-ruby}" \
      --annotation "org.opencontainers.image.revision=$(git -C "$ROOT" rev-parse HEAD)")
    ;;
  pull)
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    oras pull $ORAS_OPTS "$(ref)" -o "$tmp"
    rm -rf "$ROOT/macos/runtime"
    tar -C "$ROOT/macos" -xzf "$tmp/runtime.tar.gz"
    mkdir -p "$ROOT/macos/runtime/ccache"
    # The checkout leaves setup-runtime.sh newer than runtime/ok, which would
    # make rake rebuild the runtime we just pulled
    touch "$ROOT/macos/runtime/ok"
    ;;
  *)
    echo "Usage: $0 tag|exists|push|pull" >&2
    exit 1
    ;;
esac
