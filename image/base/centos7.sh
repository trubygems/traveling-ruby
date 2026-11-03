#!/bin/bash
# Prepares the CentOS 7 base: the build toolchain (devtoolset 9, from Software
# Collections) and the system libraries that build-ruby.sh copies into the
# package. CentOS 7 is end of life, so its packages come from vault.centos.org.
set -euxo pipefail

function use_vault()
{
	sed -i -e s/mirror.centos.org/vault.centos.org/g \
		-e 's/^#.*baseurl=http/baseurl=http/g' \
		-e 's/^mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/*.repo
	if [[ "$(uname -m)" == aarch64 ]]; then
		sed -i 's|vault.centos.org/centos/7|vault.centos.org/altarch/7|g' /etc/yum.repos.d/*.repo
	fi
}

use_vault
yum install -y epel-release centos-release-scl
# centos-release-scl adds repositories that point at mirror.centos.org
use_vault
yum install -y "devtoolset-$DEVTOOLSET_VERSION" \
	tar bzip2 xz file patch make m4 bison flex autoconf automake libtool pkgconfig \
	perl perl-core perl-IPC-Cmd python \
	wget sudo which \
	libffi readline-devel ncurses-devel

# Links OpenMP statically when linking libstdc++ statically
echo '*link_gomp: %{static|static-libgcc|static-libstdc++|static-libgfortran: libgomp.a%s; : -lgomp } %{static: -ldl }' \
	> /opt/rh/devtoolset-$DEVTOOLSET_VERSION/root/usr/lib/gcc/*-redhat-linux/$DEVTOOLSET_VERSION/libgomp.spec

yum clean all
rm -rf /var/cache/yum
