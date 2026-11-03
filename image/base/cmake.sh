#!/bin/bash
# Builds CMake from source into /usr/local for the CentOS 7 base. CentOS 7's is
# too old, and Kitware's arm64 binaries need glibc 2.28.
set -euxo pipefail

file=cmake-$CMAKE_VERSION.tar.gz
curl -fsSL -o /tmp/$file https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/$file
echo "$CMAKE_SHA256  /tmp/$file" | sha256sum -c -
mkdir /tmp/cmake
tar -xzf /tmp/$file -C /tmp/cmake --strip-components=1
cd /tmp/cmake
# enable reads unset variables such as MANPATH
set +u
source /opt/rh/devtoolset-$DEVTOOLSET_VERSION/enable
set -u
./bootstrap --prefix=/usr/local --parallel="$(nproc)" -- \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_USE_OPENSSL=OFF -DBUILD_TESTING=OFF \
	-DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc"
make -j"$(nproc)"
make install
rm -rf /usr/local/doc /usr/local/man /tmp/cmake /tmp/$file
