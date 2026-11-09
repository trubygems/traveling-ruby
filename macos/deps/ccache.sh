# https://github.com/ccache/ccache/releases
NAME=ccache
VERSION=4.14.3
URL=https://github.com/ccache/ccache/releases/download/v$VERSION/ccache-$VERSION-darwin.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://api.github.com/repos/ccache/ccache/releases?per_page=100 "tag_name":\s*"v(?<version>\d+\.\d+\.\d+)"'
SHA256=764dd2a8100ff83e6bbd7b9a1e2016cc401be34bee8a70ea99698186622c34d5
DEPS=

# Upstream's universal binary. internal/bin/cc uses it for every later unit.
function build()
{
	fetch
	run mkdir -p "$RUNTIME_DIR/bin"
	run cp ccache-$VERSION-darwin/ccache "$RUNTIME_DIR/bin/"
}
