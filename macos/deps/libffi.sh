# https://github.com/libffi/libffi/releases/
NAME=libffi
VERSION=3.8.0
URL=https://github.com/libffi/libffi/releases/download/v$VERSION/libffi-$VERSION.tar.gz
SHA256=7da3e2d9a171eb0a038f592ecad3ff2bb2550f3496d87b3b29ad0cf4430c0db4
DEPS=

function build()
{
	fetch
	cd libffi-$VERSION
	CFLAGS="-O3 -fomit-frame-pointer -fstrict-aliasing -ffast-math -Wall -fexceptions -fPIC" \
		configure --disable-static --enable-portable-binary
	run make -j$CONCURRENCY
	run make install-strip
	rpath_id libffi.8.dylib
}
