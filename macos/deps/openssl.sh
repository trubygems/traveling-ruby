# https://openssl-library.org/source/ (3.5 is the current LTS)
NAME=openssl
VERSION=3.5.9
URL=https://github.com/openssl/openssl/releases/download/openssl-$VERSION/openssl-$VERSION.tar.gz
SHA256=603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a
DEPS=

function build()
{
	fetch
	cd openssl-$VERSION
	run ./Configure "$BUILD_TARGET" --prefix="$RUNTIME_DIR" --libdir=lib \
		--openssldir="$RUNTIME_DIR/openssl" threads zlib shared no-tests no-docs
	run make -j$CONCURRENCY
	run make install_sw

	cd "$RUNTIME_DIR"
	run chmod u+rw lib/libssl.3.dylib lib/libcrypto.3.dylib
	run rm lib/libcrypto.a lib/libssl.a
	run strip bin/openssl
	run strip -S lib/libcrypto.3.dylib lib/libssl.3.dylib
	rpath_id libssl.3.dylib libcrypto.3.dylib
	run install_name_tool -change "$RUNTIME_DIR/lib/libcrypto.3.dylib" \
		"@rpath/libcrypto.3.dylib" lib/libssl.3.dylib
	run sed -i '' 's/^Libs:.*/Libs: -L${libdir} -lcrypto -lz -ldl -lpthread/' lib/pkgconfig/libcrypto.pc
	run sed -i '' '/^Libs.private:.*/d' lib/pkgconfig/libcrypto.pc
}
