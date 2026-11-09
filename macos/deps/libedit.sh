# https://thrysoee.dk/editline/
NAME=libedit
VERSION=20260512-3.1
URL=https://thrysoee.dk/editline/libedit-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://thrysoee.dk/editline/ libedit-(?<version>\d{8}-3\.1)\.tar\.gz'
SHA256=432d5e7ea8b0116dd39f2eca7bc11d0eed77faa6b77ea526ace89907c23ea4a0
DEPS=ncurses

function build()
{
	fetch
	cd libedit-$VERSION
	configure --disable-static --enable-widec
	run make -j$CONCURRENCY
	run make install-strip

	cd "$RUNTIME_DIR/lib"
	run ln -sf libedit.0.dylib libreadline.dylib
	rpath_id libedit.0.dylib
}
