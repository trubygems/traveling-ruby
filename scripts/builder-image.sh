#!/bin/bash
# Makes the Linux builder image for $PLATFORM and $ARCH available to the build
# when its tag is not on Docker Hub yet, using the Actions cache that the
# Builder images workflow also fills.
#   cache: build the image into the cache
#   load:  build the image from the cache into the local Docker
set -euo pipefail

cd "$(dirname "$0")/../image"
version=$(sed -n 's/^IMAGE_VERSION = "\(.*\)"$/\1/p' "../$PLATFORM/Rakefile")
image="you54f/traveling-ruby-builder-$ARCH:$version"

if docker buildx imagetools inspect "$image" > /dev/null 2>&1; then
	echo "$image is published"
	exit 0
fi

case "$1" in
cache) output=(--set "*.cache-to=type=gha,mode=max,scope=$PLATFORM-$ARCH" --set "*.output=type=cacheonly") ;;
load) output=(--load) ;;
*) echo "Usage: $0 cache|load" >&2; exit 1 ;;
esac

IMAGE_VERSION=${version%-*} docker buildx bake "${output[@]}" \
	--set "*.cache-from=type=gha,scope=$PLATFORM-$ARCH" \
	"$PLATFORM-$ARCH"
