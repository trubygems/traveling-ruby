# https://download.gnome.org/sources/libxml2/
NAME=libxml2
VERSION=2.15.4
URL=https://download.gnome.org/sources/libxml2/${VERSION%.*}/libxml2-$VERSION.tar.xz
SHA256=98087fd181d9070724f3fbc65c7377db03038eb92bd882374daff44940138821
DEPS=pkg-config

function build()
{
	fetch
	cd libxml2-$VERSION
	configure --disable-shared --enable-static --without-python --without-readline \
		--without-debug --with-c14n --with-threads \
		CFLAGS="-w -O2 -fPIC -fvisibility=hidden"
	run make -j$CONCURRENCY
	run make install-strip
}
