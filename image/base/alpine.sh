#!/bin/sh
# Prepares the Alpine base: the build toolchain and the system libraries that
# build-ruby.sh copies into the package
set -eux

apk add --no-cache bash build-base linux-headers \
	findutils tar bzip2 xz file patch m4 bison flex autoconf automake libtool pkgconf cmake \
	perl python3 curl \
	wget sudo \
	libffi readline-dev ncurses-dev
# libcheck and setuser run with /usr/bin/python
ln -sf python3 /usr/bin/python
