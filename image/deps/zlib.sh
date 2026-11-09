# https://zlib.net/
NAME=zlib
VERSION=1.4
URL=https://zlib.net/fossils/zlib-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://zlib.net/fossils/ zlib-(?<version>\d+\.\d+(?:\.\d+)*)\.tar\.gz'
SHA256=02dd159783677a749c04adbdd02b55b8a2bcc7e054f51b76b549199a916ad584

function build()
{
	fetch
	cd zlib-$VERSION
	CFLAGS="$STATICLIB_CFLAGS" run ./configure --prefix="$PREFIX" --static
	run make -j"$CONCURRENCY"
	run make install
}
