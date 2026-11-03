# https://mariadb.com/downloads/connectors/connectors-data-access/c-connector
# Stands in for the MySQL client library: the mysql2 gem builds against either
NAME=mariadb
VERSION=3.4.11
URL=https://archive.mariadb.org/connector-c-$VERSION/mariadb-connector-c-$VERSION-src.tar.gz
SHA256=521c0712e9291fa96558df9e2ff431376a3a79329f13751896b694cae12765b4
DEPS="cmake openssl"

function build()
{
	local plugin

	fetch
	cd mariadb-connector-c-$VERSION-src
	# Static library only, with the authentication plugins built in so
	# nothing is loaded from a plugin directory at run time
	local plugins=()
	for plugin in DIALOG CLIENT_ED25519 CACHING_SHA2_PASSWORD SHA256_PASSWORD \
		MYSQL_CLEAR_PASSWORD MYSQL_OLD_PASSWORD PARSEC; do
		plugins+=(-DCLIENT_PLUGIN_$plugin=STATIC)
	done
	# ZLIB_LIBRARY=z gives a plain -lz: otherwise an absolute SDK path to
	# libz.tbd ends up in mariadb_config --libs_sys
	run cmake -S . -B build -DCMAKE_INSTALL_PREFIX="$RUNTIME_DIR" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_C_FLAGS="-fPIC -fvisibility=hidden" \
		-DCMAKE_OSX_ARCHITECTURES=$ARCHITECTURE -DCMAKE_OSX_DEPLOYMENT_TARGET=12.2 \
		-DWITH_SSL=OPENSSL -DOPENSSL_ROOT_DIR="$RUNTIME_DIR" -DOPENSSL_USE_STATIC_LIBS=OFF \
		-DWITH_UNIT_TESTS=OFF -DWITH_CURL=OFF -DWITH_EXTERNAL_ZLIB=ON \
		-DZLIB_LIBRARY=z \
		-DCLIENT_PLUGIN_REMOTE_IO=OFF "${plugins[@]}"
	run cmake --build build -j$CONCURRENCY
	run cmake --install build --component Development
	run cmake --install build --component Documentation 2>/dev/null || true

	cd "$RUNTIME_DIR"
	run rm -f lib/mariadb/libmariadb*.dylib
	run ln -sf libmariadbclient.a lib/mariadb/libmysqlclient.a
	run ln -sf libmariadbclient.a lib/mariadb/libmariadb.a
	run cp "$RECIPE_DIR/mysql_config" bin/mysql_config
	run chmod +x bin/mysql_config
}
