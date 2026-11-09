# https://ftp.gnu.org/gnu/m4/
NAME=m4
VERSION=1.4.21
URL=https://ftp.gnu.org/gnu/m4/m4-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://ftp.gnu.org/gnu/m4/ m4-(?<version>\d+\.\d+(?:\.\d+)?)\.tar\.gz'
SHA256=38ae59f7a30bf9c108193cc5c25fbb06014f21e230c7ede2eff614f7b7c37ed8
DEPS=

function build()
{
	fetch
	cd m4-$VERSION
	run ./configure --prefix="$RUNTIME_DIR"
	run make -j$CONCURRENCY
	run make install
}
