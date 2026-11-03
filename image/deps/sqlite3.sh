# https://www.sqlite.org/download.html
NAME=sqlite3
VERSION=3540100
URL=https://www.sqlite.org/2026/sqlite-autoconf-$VERSION.tar.gz
SHA256=926ef8d3eab93fbf6e06011901273eec076b25594a4e1cdadd50c987f4f6d64e

function build()
{
	fetch
	cd sqlite-autoconf-$VERSION
	run ./configure --prefix="$PREFIX" --enable-static --disable-shared \
		--disable-load-extension CFLAGS="$STATICLIB_CFLAGS"
	run make -j"$CONCURRENCY"
	run make install
	run rm -f "$PREFIX/bin/sqlite3"
}
