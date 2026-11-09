# syntax=docker/dockerfile:1
#
# The image that Ruby is built in for Linux, from the Holy Build Box approach
# (https://github.com/phusion/holy-build-box): an old C library, so binaries run
# on any newer Linux, and static libraries built with -fPIC for the native
# extensions to link.
#
# Each dependency is built in its own stage from deps/<name>.sh, with only the
# dependencies it is built against copied in, so changing one recipe only
# rebuilds that dependency (and those built against it) before the final stage
# copies them all together.
#
# DISTRO is centos7 (glibc, for linux/) or alpine (musl, for linux-musl/).
# Build with docker buildx bake, see docker-bake.hcl.

ARG DISTRO=centos7

FROM centos:7 AS toolchain-centos7
ENV DEVTOOLSET_VERSION=9
COPY base/centos7.sh /tmp/
RUN /tmp/centos7.sh && rm /tmp/centos7.sh

FROM toolchain-centos7 AS cmake-centos7
ARG CMAKE_VERSION=4.4.5 CMAKE_SHA256=a0c54c88abb8078dd8eccadb717fc6bb194bf18e7d44c86309910288886e04e2
COPY base/cmake.sh /tmp/
RUN /tmp/cmake.sh && rm /tmp/cmake.sh

FROM toolchain-centos7 AS base-centos7
COPY --from=cmake-centos7 /usr/local/ /usr/local/

FROM alpine:3.15 AS base-alpine
COPY base/alpine.sh /tmp/
RUN /tmp/alpine.sh && rm /tmp/alpine.sh

FROM base-${DISTRO} AS base
ARG CCACHE_VERSION=4.14.3
COPY hbb/activate_func.sh hbb/activate-exec /hbb/
COPY hbb/hbb-activate /hbb/activate
COPY hbb/libcheck hbb/hardening-check hbb/setuser /hbb/bin/
COPY hbb/activate-exec /hbb_shlib/
COPY hbb/shlib-activate /hbb_shlib/activate
COPY build-dep /usr/local/bin/
RUN set -eux; \
	case "$(uname -m)" in \
	x86_64) sha=d553fac006ed93a37342cee9228cf4e13dd66690fa1a8075c54c7bace9b72ae6 ;; \
	aarch64) sha=f13e56bdb02f62b6f08f54ac527a0a7674dff22ea607167f33621fe2f2ded37b ;; \
	esac; \
	file=ccache-$CCACHE_VERSION-linux-$(uname -m)-musl-static.tar.xz; \
	curl -fsSL -o /tmp/$file https://github.com/ccache/ccache/releases/download/v$CCACHE_VERSION/$file; \
	echo "$sha  /tmp/$file" | sha256sum -c -; \
	tar -xJf /tmp/$file -C /hbb/bin --strip-components=1 --wildcards '*/ccache'; \
	rm /tmp/$file

# One stage per dependency. COPY --from brings in what a dependency is built
# against.

FROM base AS zlib
COPY deps/zlib.sh /deps/
RUN build-dep zlib

FROM base AS openssl
COPY --from=zlib /out/ /
COPY deps/openssl.sh /deps/
RUN build-dep openssl

FROM base AS libstdcxx
COPY deps/libstdcxx.sh /deps/
RUN build-dep libstdcxx

FROM base AS sqlite3
COPY deps/sqlite3.sh /deps/
RUN build-dep sqlite3

FROM base AS libyaml
COPY deps/libyaml.sh /deps/
RUN build-dep libyaml

FROM base AS libffi
COPY deps/libffi.sh /deps/
RUN build-dep libffi

FROM base AS icu
COPY deps/icu.sh /deps/
RUN build-dep icu

FROM base AS libpq
COPY --from=zlib /out/ /
COPY deps/libpq.sh /deps/
RUN build-dep libpq

FROM base AS mariadb
COPY --from=zlib /out/ /
COPY --from=openssl /out/ /
COPY deps/mariadb.sh /deps/
COPY deps/mariadb /deps/mariadb/
RUN build-dep mariadb

FROM base AS libssh2
COPY --from=zlib /out/ /
COPY --from=openssl /out/ /
COPY deps/libssh2.sh /deps/
RUN build-dep libssh2

# Rust, for YJIT
FROM base AS rust
ARG RUST_VERSION=1.99.1 RUSTUP_VERSION=1.29.3
ENV RUSTUP_HOME=/usr/local/rustup CARGO_HOME=/usr/local/cargo
RUN set -eux; \
	libc=gnu; [ -f /etc/alpine-release ] && libc=musl; \
	target=$(uname -m)-unknown-linux-$libc; \
	case "$target" in \
	x86_64-unknown-linux-gnu) sha=b1c8cb14e30889e7e2999e6b69e62d9e9b9ffc0f4df8180564d306d9680e6c55 ;; \
	aarch64-unknown-linux-gnu) sha=9f608c142e0e38a78957d0661ba1dfaf0b6fb37184cfaa4b9a0aa57af6184282 ;; \
	x86_64-unknown-linux-musl) sha=1552169aba2836777136ccff7a381e95c17233b5d8250cd5e10ae3cb971bfcfc ;; \
	aarch64-unknown-linux-musl) sha=956deacdc27ab82ae7ac821d5d3e9e95e4795d476d17efe99743bb8531ca1031 ;; \
	esac; \
	curl -fsSL -o /tmp/rustup-init https://static.rust-lang.org/rustup/archive/$RUSTUP_VERSION/$target/rustup-init; \
	echo "$sha  /tmp/rustup-init" | sha256sum -c -; \
	chmod +x /tmp/rustup-init; \
	/tmp/rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION; \
	rm /tmp/rustup-init; \
	/usr/local/cargo/bin/rustc --version

FROM base
ENV RUSTUP_HOME=/usr/local/rustup CARGO_HOME=/usr/local/cargo \
	PATH=/usr/local/cargo/bin:$PATH
COPY --from=rust /usr/local/rustup /usr/local/rustup
COPY --from=rust /usr/local/cargo /usr/local/cargo
COPY --from=zlib /out/ /
COPY --from=openssl /out/ /
COPY --from=libstdcxx /out/ /
COPY --from=sqlite3 /out/ /
COPY --from=libyaml /out/ /
COPY --from=libffi /out/ /
COPY --from=icu /out/ /
COPY --from=libpq /out/ /
COPY --from=mariadb /out/ /
COPY --from=libssh2 /out/ /
RUN set -eux; \
	case "$(uname -m)" in aarch64) echo arm64 ;; *) uname -m ;; esac > /ARCHITECTURE; \
	mkdir -p /ccache; \
	if [ -f /etc/alpine-release ]; then \
		addgroup -g 1000 app && adduser -D -u 1000 -G app -g App app; \
	else \
		groupadd -g 1000 app && useradd -u 1000 -g 1000 -c App app; \
	fi
