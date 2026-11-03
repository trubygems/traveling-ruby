# https://www.libssh2.org/download/
NAME=libssh2
VERSION=1.11.1
URL=https://www.libssh2.org/download/libssh2-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://libssh2.org/download/ libssh2-(?<version>\d+\.\d+\.\d+)\.tar\.gz'
SHA256=d9ec76cbe34db98eec3539fe2c899d26b0c837cb3eb466a56b0f109cabf658f7
DEPS="openssl pkg-config"

function build()
{
	fetch
	cd libssh2-$VERSION
	configure --enable-static --disable-shared --with-crypto=openssl --with-libz \
		--disable-examples-build --disable-debug --disable-docker-tests --disable-sshd-tests \
		CFLAGS="-w -O2 -fPIC -fvisibility=hidden"
	run make -j$CONCURRENCY
	run make install-strip
}
