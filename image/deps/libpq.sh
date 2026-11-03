# https://www.postgresql.org/ftp/source/
NAME=libpq
VERSION=18.6
URL=https://ftp.postgresql.org/pub/source/v$VERSION/postgresql-$VERSION.tar.bz2
SHA256=555610c24d53e4316da5b7d3fc25c279d96856d5e0e23ee308c328c5fa881d9f

function build()
{
	fetch
	cd postgresql-$VERSION
	run ./configure --prefix="$PREFIX" --without-icu --without-readline \
		CFLAGS="$STATICLIB_CFLAGS"
	# PostgreSQL's build system sometimes fails when building with
	# concurrency, so we don't do it.
	run make -C src/backend generated-headers
	run make -C src/common
	run make -C src/port
	run make -C src/interfaces/libpq
	run make -C src/interfaces/libpq install-strip
	run make -C src/include install
	run make -C src/bin/pg_config install-strip

	# One static libpq.a with its helper libraries merged in, and no shared
	# library
	run rm "$PREFIX"/lib/libpq.*
	run mkdir libpq-tmp
	cd libpq-tmp
	run ar -x ../src/interfaces/libpq/libpq.a
	# The _shlib variants, which libpq itself links: the frontend libpgcommon.a
	# renames the encoding functions libpq calls to *_private
	run ar -x ../src/common/libpgcommon_shlib.a
	run ar -x ../src/port/libpgport_shlib.a
	run ar -qs "$PREFIX"/lib/libpq.a ./*.o
	run strip --strip-debug "$PREFIX"/lib/libpq.a
}
