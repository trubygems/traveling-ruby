# libstdc++ built with -fPIC, so that native extensions can link it statically
# (-static-libstdc++), from the GCC release that devtoolset 9 is based on
NAME=libstdcxx
VERSION=9.3.0
URL=https://ftpmirror.gnu.org/gcc/gcc-$VERSION/gcc-$VERSION.tar.gz
SHA256=5258a9b6afe9463c2e56b9e8355b1a4bee125ca828b8078f910303bc2ef91fa6

function build()
{
	fetch
	run mkdir gcc-build
	cd gcc-build
	export CFLAGS="$STATICLIB_CFLAGS"
	export CXXFLAGS="$STATICLIB_CXXFLAGS -Iinclude/bits"
	# configure is run twice, as the first run does not detect threads
	run ../gcc-$VERSION/libstdc++-v3/configure --prefix="$PREFIX" \
		--disable-multilib --disable-libstdcxx-visibility --disable-shared
	run ../gcc-$VERSION/libstdc++-v3/configure --prefix="$PREFIX" \
		--disable-multilib --disable-libstdcxx-visibility --disable-shared
	run grep -q '^#define _GLIBCXX_HAS_GTHREADS 1$' config.h
	run make -j"$CONCURRENCY"
	run mkdir -p "$PREFIX/lib"
	run cp src/.libs/libstdc++.a libsupc++/.libs/libsupc++.a "$PREFIX/lib/"
}
