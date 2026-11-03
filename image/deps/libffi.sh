# https://github.com/libffi/libffi/releases
NAME=libffi
VERSION=3.8.0
URL=https://github.com/libffi/libffi/releases/download/v$VERSION/libffi-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://api.github.com/repos/libffi/libffi/releases?per_page=100 "tag_name":\s*"v(?<version>\d+\.\d+\.\d+)"'
SHA256=7da3e2d9a171eb0a038f592ecad3ff2bb2550f3496d87b3b29ad0cf4430c0db4

function build()
{
	fetch
	cd libffi-$VERSION
	run ./configure --prefix="$PREFIX" --libdir="$PREFIX/lib" --disable-shared --enable-static \
		--with-pic=yes --disable-dependency-tracking --disable-docs \
		CFLAGS="$STATICLIB_CFLAGS"
	run make -j"$CONCURRENCY"
	run make install-strip
}
