# https://ftp.gnu.org/gnu/automake/
NAME=automake
VERSION=1.18.1
URL=https://ftp.gnu.org/gnu/automake/automake-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://ftp.gnu.org/gnu/automake/ automake-(?<version>\d+\.\d+(?:\.\d+)?)\.tar\.gz'
SHA256=63e585246d0fc8772dffdee0724f2f988146d1a3f1c756a3dc5cfbefa3c01915
DEPS=autoconf

function build()
{
	fetch
	cd automake-$VERSION
	configure
	run make -j$CONCURRENCY
	run make install-strip
}
