#!/bin/sh
# Works out what the build workflow should do and writes it to $GITHUB_OUTPUT.
#
# Inputs (environment):
#   EVENT          github.event_name
#   PLATFORMS      platforms to build on workflow_dispatch, e.g. "linux macos" (default: all)
#   RUBY_VERSIONS  Ruby versions to build on workflow_dispatch, e.g. "3.4.12" (default: all)
#   LABELS         JSON array of pull request labels; "build:<platform>" labels limit
#                  a pull request to those platforms
#   PUBLISH        "true" when the build will be published
#
# Ruby versions and their revisions come from versions/*.txt only.

set -e

SELFDIR=$(cd "$(dirname "$0")" && pwd)
VERSIONS_DIR="$SELFDIR/../versions"
PLATFORMS_ALL="linux linux-musl macos windows windows-via-unix"
GITHUB_OUTPUT=${GITHUB_OUTPUT:-/dev/stdout}

all_versions=$(jq -Rsc '[splits("\\s+")] | map(select(length > 0))' < "$VERSIONS_DIR/RUBY_VERSIONS.txt")
semver='split(".") | map(tonumber)'
# The newest Ruby's linux-x86_64 release is marked latest when published
latest=$(echo "$all_versions" | jq -r "max_by($semver)")
ruby_versions=$all_versions
if [ "$EVENT" = "workflow_dispatch" ] && [ -n "$RUBY_VERSIONS" ] && [ "$RUBY_VERSIONS" != all ]; then
  ruby_versions=$(echo "$RUBY_VERSIONS" | jq -Rc --argjson all "$all_versions" '[splits("[\\s,]+") | select(length > 0)] as $want |
    ($want - $all) as $unknown |
    if ($unknown | length) > 0 then error("not in versions/RUBY_VERSIONS.txt: \($unknown | join(" "))") else $all - ($all - $want) end')
fi
# Each version's revision (versions/RUBY_REVISIONS.txt, default 0); packages are named <version>-<revision>
revisions=$(jq -Rsc --argjson all "$all_versions" '
  [splits("\n") | capture("^(?<v>\\S+)\\s+(?<r>\\d+)")] | map({(.v): .r}) | add // {} |
  . as $r | $all | map({(.): ($r[.] // "0")}) | add' < "$VERSIONS_DIR/RUBY_REVISIONS.txt")
# The newest version being built, whose -full packages are tested
newest=$(echo "$ruby_versions" | jq -r "max_by($semver)")
# RubyInstaller ships arm64 builds from Ruby 3.4 and has no x86 build from Ruby 4.0
ruby_versions_arm64=$(echo "$ruby_versions" | jq -c "map(select(($semver) >= [3, 4]))")
ruby_versions_x86=$(echo "$ruby_versions" | jq -c "map(select(($semver) < [4]))")
# The cross-built Windows packages: x86_64 and x86 for each version RubyInstaller
# has, arm64 for the newest only
via_unix_builds=$(jq -nc --argjson all "$ruby_versions" --argjson x86 "$ruby_versions_x86" --arg newest "$newest" \
  '[($all[] | {arch: "x86_64", "ruby-version": .}), ($x86[] | {arch: "x86", "ruby-version": .}), ($all | map(select(. == $newest)) | .[] | {arch: "arm64", "ruby-version": .})]')

case "$EVENT" in
  workflow_dispatch) wanted=$PLATFORMS ;;
  pull_request) wanted=$(echo "${LABELS:-[]}" | jq -r '.[] | select(startswith("build:")) | ltrimstr("build:")') ;;
esac
wanted=$(echo "${wanted:-all}" | tr ',\n' '  ')

{
  echo "ruby-versions=$ruby_versions"
  echo "ruby-versions-arm64=$ruby_versions_arm64"
  echo "revisions=$revisions"
  echo "windows-via-unix-builds=$via_unix_builds"
  echo "newest-ruby-version=$newest"
  echo "latest-ruby-version=$latest"
  for platform in $PLATFORMS_ALL; do
    case " $wanted " in
      *" all "* | *" $platform "*) build=true ;;
      *) build=false ;;
    esac
    # Cross-built Windows packages are never published
    if [ "$PUBLISH" = "true" ] && [ "$platform" = "windows-via-unix" ]; then
      build=false
    fi
    echo "$platform=$build"
  done
} >> "$GITHUB_OUTPUT"
