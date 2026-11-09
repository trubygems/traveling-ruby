# https://ftp.gnu.org/gnu/ncurses/
NAME=ncurses
VERSION=6.6
URL=https://ftp.gnu.org/gnu/ncurses/ncurses-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://ftp.gnu.org/gnu/ncurses/ ncurses-(?<version>\d+\.\d+)\.tar\.gz'
SHA256=355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11
DEPS=pkg-config

function build()
{
	local lib

	fetch
	cd ncurses-$VERSION
	configure --with-shared --without-normal --without-cxx --without-cxx-binding \
		--without-ada --without-manpages --without-tests --enable-pc-files \
		--with-pkg-config-libdir="$RUNTIME_DIR/lib/pkgconfig" \
		--without-develop --disable-widec
	run make -j$CONCURRENCY
	run make install

	cd "$RUNTIME_DIR/lib"
	for lib in ncurses form menu panel; do
		run strip -S lib$lib.6.dylib
		rpath_id lib$lib.6.dylib
		if [[ $lib != ncurses ]]; then
			run install_name_tool -change "$RUNTIME_DIR/lib/libncurses.6.dylib" \
				"@rpath/libncurses.6.dylib" lib$lib.6.dylib
		fi
	done
	run ln -sf libncurses.6.dylib libtermcap.dylib
}
