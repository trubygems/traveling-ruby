#!/bin/sh
# Works out what the build workflow should do and writes it to $GITHUB_OUTPUT.
#
# Inputs (environment):
#   EVENT      github.event_name
#   TAG        release tag, for release events
#   PLATFORMS  platforms to build on workflow_dispatch, e.g. "linux macos" (default: all)
#   LABELS     JSON array of pull request labels; "build:<platform>" labels limit
#              a pull request to those platforms
#
# Release dates and Ruby versions come from versions/*.txt only.

set -e

SELFDIR=$(cd "$(dirname "$0")" && pwd)
VERSIONS_DIR="$SELFDIR/../versions"
PLATFORMS_ALL="linux linux-musl macos windows windows-via-unix"
GITHUB_OUTPUT=${GITHUB_OUTPUT:-/dev/stdout}

pkg_date=$(tr -d '[:space:]' < "$VERSIONS_DIR/VERSION.txt")
if [ "$EVENT" = "release" ] && [ "$TAG" != "rel-$pkg_date" ]; then
  echo "::error::Release tag $TAG does not match versions/VERSION.txt (expected rel-$pkg_date)"
  exit 1
fi

ruby_versions=$(jq -Rsc '[splits("\\s+")] | map(select(length > 0))' < "$VERSIONS_DIR/RUBY_VERSIONS.txt")
semver='split(".") | map(tonumber)'
newest=$(echo "$ruby_versions" | jq -r "max_by($semver)")
# RubyInstaller ships arm64 builds from Ruby 3.4 and has no x86 build from Ruby 4.0
ruby_versions_arm64=$(echo "$ruby_versions" | jq -c "map(select(($semver) >= [3, 4]))")
ruby_versions_x86=$(echo "$ruby_versions" | jq -c "map(select(($semver) < [4]))")
# The cross-built Windows packages: x86_64 and x86 for each version RubyInstaller
# has, arm64 for the newest only
via_unix_builds=$(jq -nc --argjson all "$ruby_versions" --argjson x86 "$ruby_versions_x86" --arg newest "$newest" \
  '[($all[] | {arch: "x86_64", "ruby-version": .}), ($x86[] | {arch: "x86", "ruby-version": .}), {arch: "arm64", "ruby-version": $newest}]')

case "$EVENT" in
  workflow_dispatch) wanted=$PLATFORMS ;;
  pull_request) wanted=$(echo "${LABELS:-[]}" | jq -r '.[] | select(startswith("build:")) | ltrimstr("build:")') ;;
  release) wanted=all ;;
esac
wanted=$(echo "${wanted:-all}" | tr ',\n' '  ')

{
  echo "pkg-date=$pkg_date"
  echo "ruby-versions=$ruby_versions"
  echo "ruby-versions-arm64=$ruby_versions_arm64"
  echo "windows-via-unix-builds=$via_unix_builds"
  echo "newest-ruby-version=$newest"
  for platform in $PLATFORMS_ALL; do
    case " $wanted " in
      *" all "* | *" $platform "*) build=true ;;
      *) build=false ;;
    esac
    # Cross-built Windows packages are never released
    if [ "$EVENT" = "release" ] && [ "$platform" = "windows-via-unix" ]; then
      build=false
    fi
    echo "$platform=$build"
  done
} >> "$GITHUB_OUTPUT"
