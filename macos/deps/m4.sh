# https://ftp.gnu.org/gnu/m4/
NAME=m4
VERSION=1.4.20
URL=https://ftp.gnu.org/gnu/m4/m4-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://ftp.gnu.org/gnu/m4/ m4-(?<version>\d+\.\d+(?:\.\d+)?)\.tar\.gz'
SHA256=6ac4fc31ce440debe63987c2ebbf9d7b6634e67a7c3279257dc7361de8bdb3ef
DEPS=

function build()
{
	fetch
	cd m4-$VERSION
	run ./configure --prefix="$RUNTIME_DIR"
	run make -j$CONCURRENCY
	run make install
}
