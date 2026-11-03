# https://openssl-library.org/source/ (the 3.5 series is LTS)
NAME=openssl
VERSION=3.5.9
URL=https://github.com/openssl/openssl/releases/download/openssl-$VERSION/openssl-$VERSION.tar.gz
SHA256=603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a
# Built against: zlib

function build()
{
	fetch
	cd openssl-$VERSION
	# shellcheck disable=SC2086
	run ./Configure --prefix="$PREFIX" --libdir=lib --openssldir="$PREFIX/openssl" \
		threads zlib no-shared no-tests no-docs $STATICLIB_CFLAGS $LDFLAGS
	run make -j"$CONCURRENCY"
	run make install_sw

	cd "$PREFIX"
	run strip bin/openssl
	run mkdir -p /hbb/bin
	run mv bin/openssl /hbb/bin/
	run rm bin/c_rehash
	# Static libcrypto needs these libraries too
	run sed -i 's/^Libs:.*/Libs: -L${libdir} -lcrypto -lz -ldl -lpthread/' lib/pkgconfig/libcrypto.pc
	run sed -i '/^Libs.private:.*/d' lib/pkgconfig/libcrypto.pc
}
