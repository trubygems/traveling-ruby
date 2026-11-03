# https://pkgconfig.freedesktop.org/releases/
NAME=pkg-config
VERSION=0.29.2
URL=https://pkgconfig.freedesktop.org/releases/pkg-config-$VERSION.tar.gz
SHA256=6fc69c01688c9458a57eb9a1664c9aba372ccda420a02bf4429fe610e7e7d591
DEPS=

function build()
{
	fetch
	cd pkg-config-$VERSION
	# The bundled glib does not build with current clang otherwise
	export CPPFLAGS="$CPPFLAGS -Wno-int-conversion"
	export CFLAGS="$CFLAGS -Wno-int-conversion"
	export CXXFLAGS="$CXXFLAGS -Wno-int-conversion"
	configure --with-internal-glib
	run make -j$CONCURRENCY
	run make install
}
