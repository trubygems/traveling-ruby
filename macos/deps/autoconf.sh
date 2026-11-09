# https://ftp.gnu.org/gnu/autoconf/
NAME=autoconf
VERSION=2.73
URL=https://ftp.gnu.org/gnu/autoconf/autoconf-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://ftp.gnu.org/gnu/autoconf/ autoconf-(?<version>\d+\.\d+(?:\.\d+)?)\.tar\.gz'
SHA256=259ddfa3bddc799cfb81489cc0f17dfdf1bd6d1505dda53c0f45ff60d6a4f9a7
DEPS=m4

function build()
{
	fetch
	cd autoconf-$VERSION
	configure
	run make -j$CONCURRENCY
	run make install-strip
}
