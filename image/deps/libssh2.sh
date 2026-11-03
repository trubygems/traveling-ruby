# https://libssh2.org/
NAME=libssh2
VERSION=1.11.1
URL=https://www.libssh2.org/download/libssh2-$VERSION.tar.gz
SHA256=d9ec76cbe34db98eec3539fe2c899d26b0c837cb3eb466a56b0f109cabf658f7
# Built against: zlib openssl

function build()
{
	fetch
	cd libssh2-$VERSION
	run ./configure --prefix="$PREFIX" --enable-static --disable-shared \
		--with-crypto=openssl --with-libz --disable-examples-build --disable-debug \
		CFLAGS="$STATICLIB_CFLAGS"
	run make -j"$CONCURRENCY"
	run make install-strip
}
