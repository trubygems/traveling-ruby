# https://ftp.gnu.org/gnu/libtool/
NAME=libtool
VERSION=2.5.4
URL=https://ftp.gnu.org/gnu/libtool/libtool-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://ftp.gnu.org/gnu/libtool/ libtool-(?<version>\d+\.\d+(?:\.\d+)?)\.tar\.gz'
SHA256=da8ebb2ce4dcf46b90098daf962cffa68f4b4f62ea60f798d0ef12929ede6adf
DEPS=m4

function build()
{
	fetch
	cd libtool-$VERSION
	configure --disable-shared --enable-static CFLAGS='-O2 -fPIC -fvisibility=hidden'
	run make -j$CONCURRENCY
	run make install-strip
}
