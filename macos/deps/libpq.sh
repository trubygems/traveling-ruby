# https://www.postgresql.org/ftp/source/
NAME=libpq
VERSION=18.6
URL=https://ftp.postgresql.org/pub/source/v$VERSION/postgresql-$VERSION.tar.bz2
# The newest release, for scripts/update-deps.sh: <page> <regex>
LATEST='https://ftp.postgresql.org/pub/source/ href="v(?<version>18\.\d+)/"'
SHA256=555610c24d53e4316da5b7d3fc25c279d96856d5e0e23ee308c328c5fa881d9f
DEPS=

function build()
{
	fetch
	cd postgresql-$VERSION
	configure PG_SYSROOT="$(xcrun --show-sdk-path)" \
		CFLAGS="-O2 -fPIC -fvisibility=hidden" --without-icu --without-readline
	# PostgreSQL's build system sometimes fails when building with
	# concurrency, so we don't do it.
	run make -C src/backend generated-headers
	run make -C src/common
	run make -C src/port
	run make -C src/interfaces/libpq
	run make -C src/interfaces/libpq install-strip
	run make -C src/include install
	run make -C src/bin/pg_config install-strip

	# One static libpq.a with its helper libraries merged in, and no dylib
	run rm "$RUNTIME_DIR"/lib/libpq.*
	run mkdir libpq-tmp
	cd libpq-tmp
	run ar -x ../src/interfaces/libpq/libpq.a
	# The _shlib variants, which libpq itself links: the frontend libpgcommon.a
	# renames the encoding functions libpq calls to *_private
	run ar -x ../src/common/libpgcommon_shlib.a
	run ar -x ../src/port/libpgport_shlib.a
	run ar -qs "$RUNTIME_DIR"/lib/libpq.a ./*.o
	run strip -x "$RUNTIME_DIR"/lib/libpq.a
}
