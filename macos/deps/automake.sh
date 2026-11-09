# https://ftp.gnu.org/gnu/automake/
NAME=automake
VERSION=1.20
URL=https://ftp.gnu.org/gnu/automake/automake-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://ftp.gnu.org/gnu/automake/ automake-(?<version>\d+\.\d+(?:\.\d+)?)\.tar\.gz'
SHA256=00c0e397a3c0096b1b9167eb4a5ecb87a66fe50888d939c4e02111e603936570
DEPS=autoconf

function build()
{
	fetch
	cd automake-$VERSION
	configure
	run make -j$CONCURRENCY
	run make install-strip
}
