# https://pyyaml.org/download/libyaml/
NAME=libyaml
VERSION=0.2.5
URL=https://pyyaml.org/download/libyaml/yaml-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://pyyaml.org/download/libyaml/ yaml-(?<version>\d+\.\d+\.\d+)\.tar\.gz'
SHA256=c642ae9b75fee120b2d96c712538bd2cf283228d2337df2cf2988e3c02678ef4
DEPS=

function build()
{
	fetch
	cd yaml-$VERSION
	configure --disable-static
	run make -j$CONCURRENCY
	run make install-strip
	rpath_id libyaml-0.2.dylib
}
