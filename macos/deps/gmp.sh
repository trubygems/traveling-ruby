# https://gmplib.org/ (GitHub's runners can't reach gmplib.org, so the GNU mirror)
NAME=gmp
VERSION=6.3.0
URL=https://ftp.gnu.org/gnu/gmp/gmp-$VERSION.tar.bz2
SHA256=ac28211a7cfb609bae2e2c8d6058d66c8fe96434f740cf6fe2e47b000d1c20cb
DEPS=m4

function build()
{
	fetch
	cd gmp-$VERSION
	configure --enable-static --without-readline --with-pic
	run make -j$CONCURRENCY
	run make install-strip
	rpath_id libgmp.10.dylib
}
