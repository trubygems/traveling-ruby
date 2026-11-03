# https://ftp.gnu.org/gnu/autoconf/
NAME=autoconf
VERSION=2.72
URL=https://ftp.gnu.org/gnu/autoconf/autoconf-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://ftp.gnu.org/gnu/autoconf/ autoconf-(?<version>\d+\.\d+(?:\.\d+)?)\.tar\.gz'
SHA256=afb181a76e1ee72832f6581c0eddf8df032b83e2e0239ef79ebedc4467d92d6e
DEPS=m4

function build()
{
	fetch
	cd autoconf-$VERSION
	configure
	run make -j$CONCURRENCY
	run make install-strip
}
