#!/bin/bash
# The Linux builder image for $PLATFORM (linux or linux-musl) and $ARCH. Its tag
# is the hash of image/, so changing anything there gives a new image, and every
# commit keeps pointing at the image it was built with.
#   name:  print the image name
#   load:  build the image into the local Docker, unless it is published
#   cache: build the image into the Actions cache, unless it is published
#   push:  build and push the image, unless it is published
# In GitHub Actions the builds use the Actions cache (scope $PLATFORM-$ARCH),
# so changing one recipe only rebuilds that dependency.
#
#   BUILDER_REPO   the image repository, without the -<arch> suffix
#                  (default: ghcr.io/trubygems/traveling-ruby-builder)
set -euo pipefail
cd "$(dirname "$0")/.."

case "$PLATFORM" in
linux) distro=centos7 ;;
linux-musl) distro=alpine ;;
*) echo "Unknown PLATFORM: $PLATFORM" >&2; exit 1 ;;
esac
repo=${BUILDER_REPO:-ghcr.io/trubygems/traveling-ruby-builder}

# The tree hash of image/ as it is on disk, uncommitted changes included. In a
# clean checkout, this is git rev-parse HEAD:image.
index=$(mktemp)
trap 'rm -f "$index"' EXIT
GIT_INDEX_FILE=$index git read-tree HEAD
GIT_INDEX_FILE=$index git add -A image
hash=$(GIT_INDEX_FILE=$index git write-tree --prefix=image/ | cut -c1-12)
image="$repo-$ARCH:$distro-$hash"

case "${1:-}" in
name) echo "$image"; exit 0 ;;
load) output=(--load) ;;
cache) output=(--set "*.output=type=cacheonly") ;;
push) output=(--push) ;;
*) echo "Usage: $0 name|load|cache|push" >&2; exit 1 ;;
esac

if docker buildx imagetools inspect "$image" > /dev/null 2>&1; then
	echo "$image is published"
	exit 0
fi

cache=()
if [[ -n "${ACTIONS_RUNTIME_TOKEN:-}" ]]; then
	cache=(--set "*.cache-from=type=gha,scope=$PLATFORM-$ARCH")
	if [[ "$1" != load ]]; then
		cache+=(--set "*.cache-to=type=gha,mode=max,scope=$PLATFORM-$ARCH")
	fi
fi
cd image
IMAGE_REPO=$repo IMAGE_TAG=$hash docker buildx bake "${output[@]}" "${cache[@]}" "$PLATFORM-$ARCH"
