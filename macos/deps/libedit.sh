# https://thrysoee.dk/editline/
NAME=libedit
VERSION=20251016-3.1
URL=https://thrysoee.dk/editline/libedit-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://thrysoee.dk/editline/ libedit-(?<version>\d{8}-3\.1)\.tar\.gz'
SHA256=21362b00653bbfc1c71f71a7578da66b5b5203559d43134d2dd7719e313ce041
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
