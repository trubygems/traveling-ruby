# https://www.sqlite.org/download.html
NAME=sqlite3
VERSION=3540100
URL=https://www.sqlite.org/2026/sqlite-autoconf-$VERSION.tar.gz
SHA256=926ef8d3eab93fbf6e06011901273eec076b25594a4e1cdadd50c987f4f6d64e
DEPS=

function build()
{
	fetch
	cd sqlite-autoconf-$VERSION
	configure --disable-shared --disable-load-extension CFLAGS='-O2 -fPIC -fvisibility=hidden'
	run make -j$CONCURRENCY
	run make install
	run strip -S "$RUNTIME_DIR/lib/libsqlite3.a"
}
