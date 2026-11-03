#!/bin/sh
# Copies each gem package out of its directory, so it can be published as
# <gem dir>-<gem>-<version>.tar.gz, e.g.
# traveling-ruby-gems-3.4.12-0-linux-x86_64/ffi-1.17.2.tar.gz becomes
# traveling-ruby-gems-3.4.12-0-linux-x86_64-ffi-1.17.2.tar.gz
set -e
cd "$PLATFORM"
for file in traveling-ruby-gems-*/*.tar.gz; do
  [ -e "$file" ] || continue
  echo "${file%%/*}-${file#*/}"
  cp "$file" "${file%%/*}-${file#*/}"
done
