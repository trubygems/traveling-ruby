# https://ftp.gnu.org/gnu/libtool/
NAME=libtool
VERSION=2.6.2
URL=https://ftp.gnu.org/gnu/libtool/libtool-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://ftp.gnu.org/gnu/libtool/ libtool-(?<version>\d+\.\d+(?:\.\d+)?)\.tar\.gz'
SHA256=24adb3aa9ae035c70faba344af57d73215eb89281045af6c7ccd307751f8b0bf
DEPS=m4

function build()
{
	fetch
	cd libtool-$VERSION
	configure --disable-shared --enable-static CFLAGS='-O2 -fPIC -fvisibility=hidden'
	run make -j$CONCURRENCY
	run make install-strip
}
