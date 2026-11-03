# https://github.com/tukaani-project/xz/releases
NAME=xz
VERSION=5.8.4
URL=https://github.com/tukaani-project/xz/releases/download/v$VERSION/xz-$VERSION.tar.gz
SHA256=0014c7886930454fe8bd4228665b51af55eeae560ea135c9c4cd33f55b2591d9
DEPS=

function build()
{
	fetch
	cd xz-$VERSION
	configure --disable-static --disable-xzdec --disable-lzmadec --disable-lzmainfo \
		--disable-lzma-links --disable-scripts --disable-doc --disable-nls
	run make -j$CONCURRENCY
	run make install-strip
	rpath_id liblzma.5.dylib
	run test -x "$RUNTIME_DIR/bin/xzcat"
}
