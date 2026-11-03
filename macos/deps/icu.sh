# https://github.com/unicode-org/icu/releases/
NAME=icu
VERSION=79.1
URL=https://github.com/unicode-org/icu/releases/download/release-$VERSION/icu4c-$VERSION-sources.tgz
SHA256=06fa63ecb521048f8082f12ad988f6b678d90cbd88aafce24cbc94902b191d99
DEPS=

function build()
{
	local flags="-w -O2 -fPIC -fvisibility=hidden -DU_CHARSET_IS_UTF8=1 -DU_USING_ICU_NAMESPACE=0"

	fetch
	cd icu/source
	configure --disable-samples --disable-tests --enable-static --disable-shared \
		--with-library-bits=64 CFLAGS="$flags" CXXFLAGS="$flags"
	run make -j$CONCURRENCY
	run make install
}
