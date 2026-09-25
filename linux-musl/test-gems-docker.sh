#!/usr/bin/env bash
set -e

SELFDIR=`dirname "$0"`
SELFDIR=`cd "$SELFDIR" && pwd`

if [ -z "$1" ]; then
    echo "Usage: $0 output/<ruby-version>-<arch> <image>"
    echo "example: $0 3.2.11-arm64"
    echo "image: alpine:latest"
    echo "image is optional|default: alpine:latest"
    exit 1
fi
IMAGE=${2:-"alpine:latest"}
if ! command -v docker &> /dev/null
then
        echo "Error: docker could not be found"
        exit 1
fi

ARCH=$(echo $1 | sed -E 's/output\///' | sed 's/.*-//')
RUBY_VERSION=$(echo $1  | sed -E 's/(-arm64|-x86_64)//' | sed -E 's/output\///')
echo "ARCH: $ARCH"
echo "RUBY_VERSION: $RUBY_VERSION"

# ## override for docker platform
[ "$ARCH" == "x86_64" ] && ARCH="amd64"

echo docker run --platform linux/"${ARCH}" --rm --entrypoint /bin/sh -v $SELFDIR/..:/home "${IMAGE}" -c "apk add bash gcc tzdata && ./home/shared/test-gems.sh home/linux-musl/"$@"";

docker run --platform linux/"${ARCH}" --rm --entrypoint /bin/sh -v $SELFDIR/..:/home "${IMAGE}" -c "apk add bash gcc tzdata && ./home/shared/test-gems.sh home/linux-musl/"$@"";

# tzinfo required for et-orbi / fugit
# gcc required for
# - charlock_holmes
# - mysql2
# - unf_ext
# Error loading shared library libgcc_s.so.1: No such file or directory