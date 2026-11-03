#!/bin/sh
# Stores the units of the macOS runtime (one per recipe in macos/deps) as OCI
# artifacts in a registry, so every branch, pull request and release reuses one
# build of each. macos/setup-runtime.sh calls this when RUNTIME_REPO is set.
#
# Usage:
#   macos-runtime.sh unit-exists ARCH NAME KEY       exit 0 if the registry has the unit
#   macos-runtime.sh unit-pull ARCH NAME KEY FILE    pull the unit's tarball to FILE
#   macos-runtime.sh unit-push ARCH NAME KEY FILE    push FILE as the unit
#
# Each unit is tagged macos-<arch>-<name>-<key>. setup-runtime.sh computes the
# key from the unit's recipe, the toolchain and the keys of the units it is
# built against, so changing one recipe only rebuilds that unit and the units
# that depend on it.
#
# Inputs (environment):
#   RUNTIME_REPO   repository to store units in, e.g. ghcr.io/trubygems/traveling-ruby-runtime
#   ORAS_OPTS      extra oras options, e.g. --plain-http for a local registry

set -e

SELFDIR=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$SELFDIR/.." && pwd)
MEDIA_TYPE=application/vnd.traveling-ruby.runtime.tar+gzip

usage() {
  sed -n 's/^#   macos-runtime.sh /Usage: macos-runtime.sh /p' "$0" >&2
  exit 1
}

ref() {
  : "${RUNTIME_REPO:?set RUNTIME_REPO to the repository to store units in}"
  echo "$RUNTIME_REPO:macos-$1-$2-$3"
}

case "$1" in
  unit-exists)
    [ $# -eq 4 ] || usage
    oras manifest fetch $ORAS_OPTS "$(ref "$2" "$3" "$4")" > /dev/null 2>&1
    ;;
  unit-pull)
    [ $# -eq 5 ] || usage
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    if ! oras pull $ORAS_OPTS "$(ref "$2" "$3" "$4")" -o "$tmp" > /dev/null 2>&1; then
      echo "Not in the registry: $(ref "$2" "$3" "$4")"
      exit 1
    fi
    echo "Pulled $(ref "$2" "$3" "$4")"
    mv "$tmp/unit.tar.gz" "$5"
    ;;
  unit-push)
    [ $# -eq 5 ] || usage
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    cp "$5" "$tmp/unit.tar.gz"
    (cd "$tmp" && oras push $ORAS_OPTS --artifact-type application/vnd.traveling-ruby.runtime "$(ref "$2" "$3" "$4")" "unit.tar.gz:$MEDIA_TYPE" \
      --annotation "org.opencontainers.image.source=${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-trubygems/traveling-ruby}" \
      --annotation "org.opencontainers.image.revision=$(git -C "$ROOT" rev-parse HEAD)" > /dev/null)
    echo "Pushed $(ref "$2" "$3" "$4")"
    ;;
  *)
    usage
    ;;
esac
