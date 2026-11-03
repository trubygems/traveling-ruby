# Sourced by setup-runtime.sh, in a subshell, after each recipe in deps/
#
# A recipe sets NAME, VERSION, URL, SHA256 and DEPS (the units whose files it
# builds against) and defines build(), which runs in an empty temporary
# directory and installs into $RUNTIME_DIR. Files in deps/<name>/ (patches)
# are part of the recipe.
#
# This file is part of every unit's cache key, so keep it small: a change here
# rebuilds the whole runtime.
#
# Inputs (environment): SELFDIR RUNTIME_DIR ARCHITECTURE CONCURRENCY CACHE_DIR

if [[ "$ARCHITECTURE" == "x86_64" ]]; then
	BUILD_TARGET="darwin64-x86_64-cc"
	DEPLOY_TARGET="x86_64-apple-darwin22"
elif [[ "$ARCHITECTURE" == "arm64" ]]; then
	BUILD_TARGET="darwin64-arm64-cc"
	DEPLOY_TARGET="aarch64-apple-darwin22"
fi
RECIPE_DIR="$SELFDIR/deps/$NAME"

export PATH="$RUNTIME_DIR/bin:$PATH"
export LIBRARY_PATH="$RUNTIME_DIR/lib"
export PKG_CONFIG_PATH="$RUNTIME_DIR/lib/pkgconfig:/usr/lib/pkgconfig"
export RUNTIME_DIR
export DEAD_STRIP=true
export CCACHE_DIR="$RUNTIME_DIR/ccache"
export CCACHE_COMPRESS=1
export CCACHE_COMPRESS_LEVEL=3
export CPPFLAGS="-Wno-error=unused-command-line-argument"
export CFLAGS="-Wno-error=unused-command-line-argument"
export CXXFLAGS="-Wno-error=unused-command-line-argument"

# Downloads $URL into $CACHE_DIR (once), checks it against $SHA256 and
# extracts it into the current directory.
function fetch()
{
	local file="$CACHE_DIR/${URL##*/}"
	local sum

	mkdir -p "$CACHE_DIR"
	if [[ ! -e "$file" ]]; then
		run curl --fail -sSL -o "$file.part" "$URL"
		mv "$file.part" "$file"
	fi
	sum=$(shasum -a 256 "$file" | cut -d' ' -f1)
	if [[ "$SHA256" == "" ]]; then
		warning "$NAME: no SHA256 in deps/$NAME.sh; the download's is $sum"
	elif [[ "$sum" != "$SHA256" ]]; then
		rm -f "$file"
		error "$NAME: $URL has SHA256 $sum, expected $SHA256"
		return 1
	fi
	run tar -xf "$file"
}

# ./configure for this runtime
function configure()
{
	run ./configure --prefix="$RUNTIME_DIR" --build="$DEPLOY_TARGET" "$@"
}

# Sets each library's install name to @rpath/<file>, so it loads from next to
# the Ruby binary once packaged
function rpath_id()
{
	local lib
	for lib in "$@"; do
		run install_name_tool -id "@rpath/$lib" "$RUNTIME_DIR/lib/$lib"
	done
}
