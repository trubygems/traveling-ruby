#!/bin/bash
# Publishes built packages to one release per Ruby version, revision and target,
# tagged ruby-<ruby version>-<revision>-<target>, e.g. ruby-3.4.12-0-linux-x86_64.
#
# A release is created the first time its runtime is published. Later runs only
# add assets the release lacks (new gem versions), so published files never
# change and pinned gem versions stay downloadable. Each release carries a
# SHA256SUMS and a manifest.json covering all of its assets.
#
# Usage: publish-releases.sh <dir of traveling-ruby*.tar.gz>
#
# Inputs (environment):
#   GITHUB_TOKEN       token with contents: write
#   GITHUB_API_URL     API base URL (GitHub or Gitea)
#   GITHUB_REPOSITORY  owner/repo
#   GITHUB_SHA         commit new release tags point at
#   NEWEST_RUBY        newest Ruby version; its linux-x86_64 release is marked latest when created
#   MAX_ASSETS         refuse to grow a release past this many assets (default 950; GitHub's limit is 1000)
#   DRY_RUN            set to print what would be published without changing anything

set -euo pipefail

DIST=$(cd "$1" && pwd)
MAX_ASSETS=${MAX_ASSETS:-950}
API="$GITHUB_API_URL/repos/$GITHUB_REPOSITORY"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Prints the response body; on an HTTP error, prints it to stderr and fails.
api() {
  local method=$1 url=$2 body
  shift 2
  if body=$(curl -sS --fail-with-body --retry 3 -X "$method" -H "Authorization: token $GITHUB_TOKEN" -H 'Accept: application/json' "$@" "$url"); then
    printf '%s\n' "$body"
  else
    echo "$method ${url%%\?*}: $body" >&2
    return 1
  fi
}

# Every asset of a release as {id, name, browser_download_url}. GitHub pages the
# list; Gitea returns all of it on every page, so stop once a page adds nothing new.
list_assets() {
  local release_id=$1 page=1 all='[]' batch before
  while :; do
    batch=$(api GET "$API/releases/$release_id/assets?per_page=100&page=$page")
    before=$(jq length <<< "$all")
    all=$(jq -c --argjson b "$batch" '(. + $b) | unique_by(.id)' <<< "$all")
    [ "$(jq length <<< "$batch")" -lt 100 ] || [ "$(jq length <<< "$all")" -eq "$before" ] && break
    page=$((page + 1))
  done
  jq -c 'map({id, name, browser_download_url})' <<< "$all"
}

delete_asset() {
  local release_id=$1 asset_id=$2
  if [ -n "${GITEA_ACTIONS:-}" ]; then
    api DELETE "$API/releases/$release_id/assets/$asset_id" > /dev/null
  else
    api DELETE "$API/releases/assets/$asset_id" > /dev/null
  fi
}

upload_asset() {
  local upload_url=$1 file=$2
  echo "  + $(basename "$file")"
  api POST "${upload_url%%\{*}?name=$(basename "$file")" -H 'Content-Type: application/octet-stream' --data-binary "@$file" > /dev/null
}

# manifest.json from a SHA256SUMS listing the release's assets
manifest() {
  local key=$1 ruby=$2 revision=$3 target=$4
  jq -Rn --arg key "$key" --arg ruby "$ruby" --arg revision "$revision" --arg target "$target" '
    [inputs | capture("^(?<sha256>[0-9a-f]+) [ *](?<file>.+)$")] as $files |
    ($files | map(select(.file == "traveling-ruby-\($key).tar.gz")) | first) as $runtime |
    ($files | map(select(.file == "traveling-ruby-\($key)-full.tar.gz")) | first) as $full |
    {
      ruby: $ruby,
      revision: ($revision | tonumber),
      target: $target,
      runtime: $runtime,
      runtime_full: $full,
      gems: [
        $files[] | select(.file | startswith("traveling-ruby-gems-\($key)-")) |
        (.file | ltrimstr("traveling-ruby-gems-\($key)-") | rtrimstr(".tar.gz") | capture("^(?<name>.+)-(?<version>[^-]+)$")) + .
      ] | sort_by(.name, .version)
    }'
}

failed=0
cd "$DIST"
for runtime in traveling-ruby-[0-9]*.tar.gz; do
  case "$runtime" in *-full.tar.gz) continue ;; esac
  key=${runtime#traveling-ruby-}
  key=${key%.tar.gz}
  # <ruby>-<revision>-<target>
  ruby=${key%%-*}
  rest=${key#*-}
  revision=${rest%%-*}
  target=${rest#*-}
  tag="ruby-$key"
  files=("$runtime")
  [ -e "traveling-ruby-$key-full.tar.gz" ] && files+=("traveling-ruby-$key-full.tar.gz")
  for gem in traveling-ruby-gems-"$key"-*.tar.gz; do
    [ -e "$gem" ] && files+=("$gem")
  done
  echo "$tag: ${#files[@]} packages"

  if release=$(api GET "$API/releases/tags/$tag" 2> /dev/null); then
    assets=$(list_assets "$(jq -r .id <<< "$release")")
  else
    release=''
    assets='[]'
  fi

  new=()
  for f in "${files[@]}"; do
    jq -e --arg n "$f" 'any(.name == $n)' <<< "$assets" > /dev/null || new+=("$f")
  done
  if [ ${#new[@]} -eq 0 ]; then
    echo "  up to date"
    continue
  fi
  metadata=$(jq '[.[] | select(.name == "SHA256SUMS" or .name == "manifest.json")] | length' <<< "$assets")
  total=$(($(jq length <<< "$assets") - metadata + ${#new[@]} + 2))
  if [ "$total" -gt "$MAX_ASSETS" ]; then
    echo "::error::$tag would have $total assets, more than $MAX_ASSETS; bump its revision in versions/RUBY_REVISIONS.txt to start a new release"
    failed=1
    continue
  fi

  if [ -n "${DRY_RUN:-}" ]; then
    printf '  would add %s\n' "${new[@]}"
    continue
  fi

  if [ -z "$release" ]; then
    latest=false
    [ "$ruby" = "${NEWEST_RUBY:-}" ] && [ "$target" = linux-x86_64 ] && latest=true
    release=$(api POST "$API/releases" -H 'Content-Type: application/json' -d "$(jq -n \
      --arg tag "$tag" --arg sha "$GITHUB_SHA" --arg ruby "$ruby" --arg revision "$revision" --arg target "$target" --arg latest "$latest" '{
        tag_name: $tag,
        target_commitish: $sha,
        name: "Ruby \($ruby)-\($revision) \($target)",
        body: "Traveling Ruby \($ruby), revision \($revision), for \($target): the runtime, its -full variant with every supported gem, and each native gem on its own. New gem versions are added to this release as they are built; manifest.json and SHA256SUMS list everything in it.",
        make_latest: $latest
      }')")
    echo "  created release"
  fi
  release_id=$(jq -r .id <<< "$release")
  upload_url=$(jq -r .upload_url <<< "$release")
  # Gitea builds upload and download URLs from its ROOT_URL, which runners may not reach
  [ -n "${GITEA_ACTIONS:-}" ] && upload_url="$API/releases/$release_id/assets"

  # Checksums of what the release already has, plus the new files
  : > "$WORK/SHA256SUMS"
  sums=$(jq -r '.[] | select(.name == "SHA256SUMS") | .browser_download_url' <<< "$assets")
  if [ -n "$sums" ]; then
    [ -n "${GITEA_ACTIONS:-}" ] && sums="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/download/$tag/SHA256SUMS"
    curl -fsSL --retry 3 -H "Authorization: token $GITHUB_TOKEN" "$sums" > "$WORK/SHA256SUMS"
  fi
  sha256sum "${new[@]}" >> "$WORK/SHA256SUMS"
  sort -k2 -u "$WORK/SHA256SUMS" -o "$WORK/SHA256SUMS"
  manifest "$key" "$ruby" "$revision" "$target" < "$WORK/SHA256SUMS" > "$WORK/manifest.json"

  for f in "${new[@]}"; do
    upload_asset "$upload_url" "$f"
  done
  for id in $(jq -r '.[] | select(.name == "SHA256SUMS" or .name == "manifest.json") | .id' <<< "$assets"); do
    delete_asset "$release_id" "$id"
  done
  upload_asset "$upload_url" "$WORK/SHA256SUMS"
  upload_asset "$upload_url" "$WORK/manifest.json"
done
exit $failed
