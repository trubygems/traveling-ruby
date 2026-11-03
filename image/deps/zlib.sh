# https://zlib.net/
NAME=zlib
VERSION=1.3.2
URL=https://zlib.net/fossils/zlib-$VERSION.tar.gz
SHA256=bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16

function build()
{
	fetch
	cd zlib-$VERSION
	CFLAGS="$STATICLIB_CFLAGS" run ./configure --prefix="$PREFIX" --static
	run make -j"$CONCURRENCY"
	run make install
}
