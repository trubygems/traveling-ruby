# https://download.gnome.org/sources/libxslt/
NAME=libxslt
VERSION=1.1.45
URL=https://download.gnome.org/sources/libxslt/${VERSION%.*}/libxslt-$VERSION.tar.xz
SHA256=9acfe68419c4d06a45c550321b3212762d92f41465062ca4ea19e632ee5d216e
DEPS="libxml2 pkg-config"

function build()
{
	fetch
	cd libxslt-$VERSION
	configure --disable-shared --enable-static --without-python --without-debug \
		--without-debugger --without-profiler \
		CFLAGS="-w -O2 -fPIC -fvisibility=hidden"
	run make -j$CONCURRENCY
	run make install-strip
}
