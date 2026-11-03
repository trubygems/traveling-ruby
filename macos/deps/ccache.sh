# https://github.com/ccache/ccache/releases
NAME=ccache
VERSION=4.14.2
URL=https://github.com/ccache/ccache/releases/download/v$VERSION/ccache-$VERSION-darwin.tar.gz
SHA256=cf240009630b605b775c7c5c7b7105a3b196c79f31af322c1557969aa28003fc
DEPS=

# Upstream's universal binary. internal/bin/cc uses it for every later unit.
function build()
{
	fetch
	run mkdir -p "$RUNTIME_DIR/bin"
	run cp ccache-$VERSION-darwin/ccache "$RUNTIME_DIR/bin/"
}
