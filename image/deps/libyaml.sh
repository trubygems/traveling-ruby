# https://pyyaml.org/wiki/LibYAML
NAME=libyaml
VERSION=0.2.5
URL=https://pyyaml.org/download/libyaml/yaml-$VERSION.tar.gz
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://pyyaml.org/download/libyaml/ yaml-(?<version>\d+\.\d+\.\d+)\.tar\.gz'
SHA256=c642ae9b75fee120b2d96c712538bd2cf283228d2337df2cf2988e3c02678ef4

function build()
{
	fetch
	cd yaml-$VERSION
	run ./configure --prefix="$PREFIX" --enable-static --disable-shared \
		CFLAGS="$STATICLIB_CFLAGS"
	run make -j"$CONCURRENCY"
	run make install-strip
}
