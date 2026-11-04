#!/bin/bash
set -e

SELFDIR=`dirname "$0"`
SELFDIR=`cd "$SELFDIR" && pwd`
source "$SELFDIR/library.sh"
BUNDLER_VERSION=`cat "$SELFDIR/../versions/BUNDLER_VERSION.txt"`
# if [[ "$RUBY_VERSIONS" < "3.0.0" ]]; then
#     BUNDLER_VERSION="2.4.22"
# fi
BUILD_OUTPUT_DIR=
RUBY_PACKAGE=
GEM_NATIVE_EXTENSIONS_DIR=
RUBY_PACKAGE_FULL=

function load_ruby_info()
{
	local BUILD_OUTPUT_DIR="$1"
	RUBY_COMPAT_VERSION=`cat "$BUILD_OUTPUT_DIR/info/RUBY_COMPAT_VERSION"`
	GEM_PLATFORM=`cat "$BUILD_OUTPUT_DIR/info/GEM_PLATFORM"`
	GEM_EXTENSION_API_VERSION=`cat "$BUILD_OUTPUT_DIR/info/GEM_EXTENSION_API_VERSION"`
}

function find_gems_containing_native_extensions()
{
	local BUILD_OUTPUT_DIR="$1"
	(
		shopt -s nullglob
		GEMS=("$BUILD_OUTPUT_DIR"/lib/ruby/gems/$RUBY_COMPAT_VERSION/extensions/$GEM_PLATFORM/$GEM_EXTENSION_API_VERSION/*)
		GEM_NAMES=()
		for GEM in "${GEMS[@]}"; do
			GEM_NAME="`basename \"$GEM\"`"
			GEM_NAMES+=("$GEM_NAME")
		done
		echo "${GEM_NAMES[@]}"
	)
	[[ $? = 0 ]]
}

function package_platform_native_gems() {
	local BUILD_OUTPUT_DIR="$1"
	local OUTPUT_DIR="$2"
	(
			shopt -s nullglob
			local GEM_BASE="$BUILD_OUTPUT_DIR/lib/ruby/gems/$RUBY_COMPAT_VERSION/gems"
			local SPEC_BASE="$BUILD_OUTPUT_DIR/lib/ruby/gems/$RUBY_COMPAT_VERSION/specifications"
			# local EXT_BASE="$BUILD_OUTPUT_DIR/lib/ruby/gems/$RUBY_COMPAT_VERSION/extensions/$GEM_PLATFORM/$GEM_EXTENSION_API_VERSION"
			# local GEMS=("$EXT_BASE"/*)
			local PACKAGED_GEMS=()
			# # 1. Package gems with native extensions (as before)
			# for GEM_PATH in "${GEMS[@]}"; do
			# 	local GEM_NAME="$(basename "$GEM_PATH")"
			# 	local MATCHED_GEM_DIRS=("$GEM_BASE/"${GEM_NAME}*"")
			# 	local MATCHED_GEMS=()
			# 	for DIR in "${MATCHED_GEM_DIRS[@]}"; do
			# 		if [[ -d "$DIR" ]]; then
			# 			MATCHED_GEMS+=("$(basename "$DIR")")
			# 		fi
			# 	done
			# 	local MATCHED_SPECS=("$SPEC_BASE/"${GEM_NAME}*.gemspec"")
			# 	mkdir -p "$OUTPUT_DIR"
			# 	local TAR_PATH="$OUTPUT_DIR/$GEM_NAME-platform-native.tar"
			# 	local ADDED=false
			# 	for GEMDIR in "${MATCHED_GEMS[@]}"; do
			# 		tar -cf "$TAR_PATH" -C "$GEM_BASE" "$GEMDIR"
			# 		PACKAGED_GEMS+=("$GEMDIR")
			# 		ADDED=true
			# 	done
			# 	for SPEC in "${MATCHED_SPECS[@]}"; do
			# 		if [[ -f "$SPEC" ]]; then
			# 			tar -rf "$TAR_PATH" -C "$SPEC_BASE" "$(basename "$SPEC")"
			# 			ADDED=true
			# 		fi
			# 	done
			# 	if [[ "$ADDED" == true ]]; then
			# 		gzip --best --no-name -f "$TAR_PATH"
			# 		echo "Packaged $GEM_NAME with native extensions as $TAR_PATH.gz"
			# 	else
			# 		rm -f "$TAR_PATH"
			# 	fi
			# done

			# 2. Also package any gems in gems/ that contain .so or .dll files (native code), if not already packaged
			for GEMDIR in "$GEM_BASE"/*; do
				local BASENAME="$(basename "$GEMDIR")"
				# Skip if already packaged
				if [[ " ${PACKAGED_GEMS[@]} " =~ " $BASENAME " ]]; then
					continue
				fi
				# Look for .so or .dll files anywhere under the gem dir
				if find "$GEMDIR" -type f \( -name '*.so' -o -name '*.dll' \) | grep -q .; then
					mkdir -p "$OUTPUT_DIR"
					local TAR_PATH="$OUTPUT_DIR/$BASENAME.tar"
					tar -cf "$TAR_PATH" -C "$GEM_BASE" "$BASENAME"
					# Add gemspec if present
					if [[ -f "$SPEC_BASE/$BASENAME.gemspec" ]]; then
						tar -rf "$TAR_PATH" -C "$SPEC_BASE" "$BASENAME.gemspec"
					fi
					gzip --best --no-name -f "$TAR_PATH"
					echo "Packaged $BASENAME (native .so/.dll) as $TAR_PATH.gz"
				fi
			done
	)
}

function usage()
{
	echo "Usage: ./package.sh [options] <BUILD OUTPUT DIR>"
	echo "Package built Traveling Ruby binaries."
	echo
	echo "Options:"
	echo "  -r PATH    Package Ruby into given file"
	echo "  -E DIR     Package gem native extensions into the given directory"
	echo "  -f         Package Ruby with full gem set (not just default gems)"
	echo "  -h         Show this help"
}

function parse_options()
{
	local OPTIND=1
	local opt
	while getopts "r:E:hf" opt; do
		case "$opt" in
		r)
			RUBY_PACKAGE="$OPTARG"
			;;
		f)
			RUBY_PACKAGE_FULL=true
			;;
		E)
			GEM_NATIVE_EXTENSIONS_DIR="$OPTARG"
			;;
		h)
			usage
			exit
			;;
		*)
			return 1
			;;
		esac
	done

	(( OPTIND -= 1 )) || true
	shift $OPTIND || true
	BUILD_OUTPUT_DIR="$1"

	if [[ "$BUILD_OUTPUT_DIR" = "" ]]; then
		usage
		exit 1
	fi
	if [[ "$RUBY_PACKAGE" = "" && "$GEM_NATIVE_EXTENSIONS_DIR" = "" ]]; then
		echo "ERROR: you must specify either a Ruby package path (-r) or a gem native extensions directory (-E)."
		exit 1
	fi
	if [[ ! -e "$BUILD_OUTPUT_DIR" ]]; then
		echo "ERROR: $BUILD_OUTPUT_DIR doesn't exist."
		exit 1
	fi
}


parse_options "$@"


##########


export GZIP=--best
load_ruby_info "$BUILD_OUTPUT_DIR"

if
	[[ "$RUBY_PACKAGE_FULL" == "true" ]]
then
	header "Packaging Ruby with full gem set and extensions..."
	run tar -cf "$RUBY_PACKAGE.tmp" -C "$BUILD_OUTPUT_DIR" .
	echo "+ gzip --best --no-name -c $RUBY_PACKAGE.tmp > $RUBY_PACKAGE"
	gzip --best --no-name -c "$RUBY_PACKAGE.tmp" > "$RUBY_PACKAGE"
	run rm "$RUBY_PACKAGE.tmp"
	exit 0
elif [[ "$RUBY_PACKAGE" != "" ]]; then
	header "Packaging Ruby..."
	run tar -cf "$RUBY_PACKAGE.tmp" -C "$BUILD_OUTPUT_DIR" \
		--exclude "include/*" \
		--exclude "lib/ruby/gems/$RUBY_COMPAT_VERSION/extensions/*" \
		--exclude "lib/ruby/gems/$RUBY_COMPAT_VERSION/gems/*" \
		--exclude "lib/ruby/gems/$RUBY_COMPAT_VERSION/plugins/*" \
		--exclude "lib/ruby/gems/$RUBY_COMPAT_VERSION/specifications/*" \
		--exclude "lib/ruby/gems/$RUBY_COMPAT_VERSION/deplibs/*" \
		.
	run tar -rf "$RUBY_PACKAGE.tmp" -C "$BUILD_OUTPUT_DIR" \
		"./lib/ruby/gems/$RUBY_COMPAT_VERSION/gems/bundler-$BUNDLER_VERSION" \
		"./lib/ruby/gems/$RUBY_COMPAT_VERSION/specifications/bundler-$BUNDLER_VERSION.gemspec" \
		"./lib/ruby/gems/$RUBY_COMPAT_VERSION/specifications/default"
	echo "+ gzip --best --no-name -c $RUBY_PACKAGE.tmp > $RUBY_PACKAGE"
	gzip --best --no-name -c "$RUBY_PACKAGE.tmp" > "$RUBY_PACKAGE"
	run rm "$RUBY_PACKAGE.tmp"
fi

NATIVE_GEMS=(`find_gems_containing_native_extensions "$BUILD_OUTPUT_DIR"`)


if [[ "$GEM_NATIVE_EXTENSIONS_DIR" != "" ]]; then
	echo
	header "Packaging gem native extensions..."
	if [[ ${#NATIVE_GEMS[@]} -eq 0 ]]; then
		echo "There are no gems with native extensions."
	else
		run mkdir -p "$GEM_NATIVE_EXTENSIONS_DIR"
		for GEM_NAME in "${NATIVE_GEMS[@]}"; do
			GEM_NAME_WITHOUT_VERSION=`echo "$GEM_NAME" | sed -E 's/(.*)-.*/\1/'`
			run tar -cf "$GEM_NATIVE_EXTENSIONS_DIR/$GEM_NAME.tar" \
				-C "$BUILD_OUTPUT_DIR/lib/ruby/gems" \
				"$RUBY_COMPAT_VERSION/extensions/$GEM_PLATFORM/$GEM_EXTENSION_API_VERSION/$GEM_NAME"
			if [[ -e "$BUILD_OUTPUT_DIR/lib/ruby/gems/$RUBY_COMPAT_VERSION/deplibs/$GEM_PLATFORM/$GEM_NAME_WITHOUT_VERSION" ]]; then
				run tar -rf "$GEM_NATIVE_EXTENSIONS_DIR/$GEM_NAME.tar" \
					-C "$BUILD_OUTPUT_DIR/lib/ruby/gems" \
					"$RUBY_COMPAT_VERSION/deplibs/$GEM_PLATFORM/$GEM_NAME_WITHOUT_VERSION"
			fi
			run rm -f "$GEM_NATIVE_EXTENSIONS_DIR/$GEM_NAME.tar.gz"
			run gzip --best --no-name "$GEM_NATIVE_EXTENSIONS_DIR/$GEM_NAME.tar"
		done
		# Also package the full gem directories for platform-specific gems with native extensions
		# package_platform_native_gems "$BUILD_OUTPUT_DIR" "$GEM_NATIVE_EXTENSIONS_DIR"
	fi
fi
