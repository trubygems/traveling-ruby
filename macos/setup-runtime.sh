#!/bin/bash
# Sets up the runtime that Ruby is built against: the build tools and C
# libraries listed in UNITS, one recipe each in deps/<name>.sh.
#
# Each unit has a key: a hash of its recipe, the shared build scripts, the
# toolchain and the keys of the units in its DEPS. A unit is rebuilt only when
# its key changes, which also rebuilds every unit built against it; the others
# stay as they are. The files each unit installed are listed in
# <runtime>/.units/<name>.files, so a stale unit can be removed before it is
# rebuilt, and packed on its own to share through a registry (see
# scripts/macos-runtime.sh):
#
#   RUNTIME_REPO   pull each missing unit from this repository before building it
#   RUNTIME_PULL   false to build every missing unit instead of pulling it
#   RUNTIME_PUSH   true to push each unit that was built
#   ORAS_OPTS      extra oras options, e.g. --plain-http for a local registry
#
# A pulled unit that was built under another runtime path has that path
# rewritten in its text files (pkg-config files, libtool archives, scripts).
# Paths compiled into binaries are not rewritten, so pull into the same path
# that the units were built in (on CI, the checkout's macos/runtime).
set -e

SELFDIR=`dirname "$0"`
SELFDIR=`cd "$SELFDIR" && pwd`
ORIG_PATH="$PATH"
ORAS=`command -v oras || true`
source "$SELFDIR/internal/reset_environment.sh"
source "$SELFDIR/../shared/library.sh"

# Build order: each unit's DEPS come before it
UNITS=(cmake ccache pkg-config m4 autoconf automake libtool openssl ncurses
	libedit gmp libffi libyaml sqlite3 xz mariadb libpq icu libssh2 libxml2 libxslt)

TEMPDIR=
RUNTIME_DIR=
ARCHITECTURE=$(uname -m)
CONCURRENCY=$(sysctl -n hw.ncpu)
CACHE_DIR=${TR_DOWNLOAD_CACHE:-$SELFDIR/cache}
FORCE=" "
SKIP=" "

function _cleanup()
{
	if [[ "$TEMPDIR" != "" ]]; then
		rm -rf "$TEMPDIR"
	fi
}

function usage()
{
	echo "Usage: ./setup-runtime.sh [options] <RUNTIME DIR>"
	echo "Sets up the Traveling Ruby build system's runtime."
	echo
	echo "Options:"
	echo "  -a NAME   Architecture to setup (x86_64 or arm64)"
	echo "  -f UNIT   Rebuild UNIT (and the units built against it), even if it is up to date"
	echo "  -s UNIT   Leave UNIT as it is"
	echo "  -j NUM    Compilation concurrency. Default: $CONCURRENCY"
	echo "  -h        Show this help"
	echo
	echo "Units: ${UNITS[*]}"
}

function parse_options()
{
	local OPTIND=1
	local opt
	while getopts "a:f:s:j:h" opt; do
		case "$opt" in
		a)
			ARCHITECTURE=$OPTARG
			;;
		f)
			is_unit "$OPTARG" || { echo "Unknown unit: $OPTARG"; exit 1; }
			FORCE="$FORCE$OPTARG "
			;;
		s)
			is_unit "$OPTARG" || { echo "Unknown unit: $OPTARG"; exit 1; }
			SKIP="$SKIP$OPTARG "
			;;
		j)
			CONCURRENCY=$OPTARG
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
	RUNTIME_DIR="$1"

	if [[ "$RUNTIME_DIR" = "" ]]; then
		usage
		exit 1
	fi
	mkdir -p "$RUNTIME_DIR"
	RUNTIME_DIR="`cd \"$RUNTIME_DIR\" && pwd`"
}

function is_unit()
{
	[[ " ${UNITS[*]} " == *" $1 "* ]]
}

function unit_deps()
{
	(source "$SELFDIR/deps/$1.sh"; echo $DEPS)
}

# The key computed for a unit this run
function unit_key()
{
	local var="KEY_${1//-/_}"
	echo "${!var}"
}

function compute_key()
{
	local name="$1"
	local dep
	local files="deps/$name.sh internal/deps-lib.sh internal/reset_environment.sh internal/bin"

	if [[ -d "$SELFDIR/deps/$name" ]]; then
		files="$files deps/$name"
	fi
	{
		echo "$name $ARCHITECTURE $MACOSX_DEPLOYMENT_TARGET $TOOLCHAIN"
		(cd "$SELFDIR" && find $files -type f | LC_ALL=C sort | xargs shasum -a 256)
		for dep in $(unit_deps "$name"); do
			if [[ "$(unit_key "$dep")" == "" ]]; then
				echo "deps/$name.sh: $dep must be built before $name" >&2
				return 1
			fi
			echo "$dep $(unit_key "$dep")"
		done
	} | shasum -a 256 | cut -c1-16
}

# Lists every installed file with what identifies its contents, so two
# snapshots show what a build added or changed
function snapshot()
{
	(cd "$RUNTIME_DIR" && find . \( -path ./ccache -o -path ./.units -o -path ./vendor \) -prune -o \
		\( -type f -o -type l \) ! -name 'ruby-*.tar.gz' ! -path ./ok \
		-exec stat -f $'%N\t%Fm %Fc %z %i' {} +) | LC_ALL=C sort
}

function unit_installed()
{
	local name="$1"
	local file

	[[ -e "$RUNTIME_DIR/.units/$name.key" ]] || return 1
	while IFS= read -r file; do
		[[ -e "$RUNTIME_DIR/$file" || -L "$RUNTIME_DIR/$file" ]] || return 1
	done < "$RUNTIME_DIR/.units/$name.files"
}

function remove_unit()
{
	local name="$1"
	local file

	echo "Removing $name"
	if [[ ! -e "$RUNTIME_DIR/.units/$name.files" && -e "$RUNTIME_DIR/.units/$name.before" ]]; then
		# Its build failed: remove what it installed before failing
		cut -f1 "$RUNTIME_DIR/.units/$name.before" > "$TEMPDIR/before.paths"
		snapshot | cut -f1 > "$TEMPDIR/after.paths"
		LC_ALL=C comm -13 "$TEMPDIR/before.paths" "$TEMPDIR/after.paths" > "$RUNTIME_DIR/.units/$name.files"
	fi
	if [[ -e "$RUNTIME_DIR/.units/$name.files" ]]; then
		while IFS= read -r file; do
			rm -f "$RUNTIME_DIR/$file"
		done < "$RUNTIME_DIR/.units/$name.files"
	fi
	rm -f "$RUNTIME_DIR/.units/$name".*
}

function build_unit()
{
	local name="$1"
	local dir="$TEMPDIR/$name"
	local path

	snapshot > "$RUNTIME_DIR/.units/$name.before"
	run mkdir "$dir"
	(
		source "$SELFDIR/deps/$name.sh"
		source "$SELFDIR/internal/deps-lib.sh"
		cd "$dir"
		build
	)
	rm -rf "$dir"
	rm -rf "$RUNTIME_DIR"/share/{info,man,doc,gtk-doc}
	snapshot > "$TEMPDIR/after"

	LC_ALL=C comm -13 "$RUNTIME_DIR/.units/$name.before" "$TEMPDIR/after" | cut -f1 > "$RUNTIME_DIR/.units/$name.files"
	cut -f1 "$RUNTIME_DIR/.units/$name.before" > "$TEMPDIR/before.paths"
	cut -f1 "$TEMPDIR/after" > "$TEMPDIR/after.paths"
	LC_ALL=C comm -12 "$TEMPDIR/before.paths" "$RUNTIME_DIR/.units/$name.files" | while IFS= read -r path; do
		warning "$name changed $path, which an earlier unit installed"
	done
	LC_ALL=C comm -23 "$TEMPDIR/before.paths" "$TEMPDIR/after.paths" | while IFS= read -r path; do
		warning "$name removed $path, which an earlier unit installed"
	done
	echo "$RUNTIME_DIR" > "$RUNTIME_DIR/.units/$name.prefix"
	rm -f "$RUNTIME_DIR/.units/$name.before"
}

function pack_unit()
{
	local name="$1"
	local out="$2"

	{
		cat "$RUNTIME_DIR/.units/$name.files"
		echo "./.units/$name.files"
		echo "./.units/$name.prefix"
	} > "$TEMPDIR/$name.list"
	run tar -czf "$out" -C "$RUNTIME_DIR" -T "$TEMPDIR/$name.list"
}

function unpack_unit()
{
	local name="$1"
	local archive="$2"
	local old file

	run tar -xzf "$archive" -C "$RUNTIME_DIR"
	old=$(cat "$RUNTIME_DIR/.units/$name.prefix")
	if [[ "$old" != "$RUNTIME_DIR" ]]; then
		echo "Relocating $name from $old"
		while IFS= read -r file; do
			if [[ -f "$RUNTIME_DIR/$file" && ! -L "$RUNTIME_DIR/$file" ]] \
				&& grep -Iq -F "$old" "$RUNTIME_DIR/$file"; then
				OLD="$old" NEW="$RUNTIME_DIR" perl -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$RUNTIME_DIR/$file"
			fi
		done < "$RUNTIME_DIR/.units/$name.files"
		echo "$RUNTIME_DIR" > "$RUNTIME_DIR/.units/$name.prefix"
	fi
}

function runtime_oci()
{
	PATH="$ORIG_PATH" "$SELFDIR/../scripts/macos-runtime.sh" "$@"
}

parse_options "$@"
export CMAKE_OSX_ARCHITECTURES=$ARCHITECTURE
export SELFDIR RUNTIME_DIR ARCHITECTURE CONCURRENCY CACHE_DIR

if [[ "$ARCHITECTURE" != "x86_64" && "$ARCHITECTURE" != "arm64" ]]; then
	echo "*** ERROR: unknown architecture $ARCHITECTURE"
	exit 1
fi

"$SELFDIR/internal/check_requirements.sh" "$ARCHITECTURE"

if [[ ! -d "$RUNTIME_DIR/.units" ]] && [[ -e "$RUNTIME_DIR/bin" || -e "$RUNTIME_DIR/lib" ]]; then
	echo "*** ERROR: $RUNTIME_DIR was set up by an older setup-runtime.sh, which did not"
	echo "record which unit installed which file. Remove it and run this again."
	exit 1
fi
mkdir -p "$RUNTIME_DIR/.units"
TEMPDIR=`mktemp -d /tmp/traveling-ruby.XXXXXXXX`

TOOLCHAIN="clang$(/usr/bin/clang --version | sed -n 's/.*clang version \([0-9]*\).*/\1/p' | head -n 1)"
TOOLCHAIN="$TOOLCHAIN sdk$(xcrun --show-sdk-version | cut -d. -f1)"

header "Setting up Traveling Ruby's runtime for $ARCHITECTURE ($TOOLCHAIN)..."
for name in "${UNITS[@]}"; do
	printf -v "KEY_${name//-/_}" %s "$(compute_key "$name")"
done

# Remove units that are stale, forced or no longer listed, the units built
# against them first
for (( i = ${#UNITS[@]} - 1; i >= 0; i-- )); do
	name=${UNITS[$i]}
	if [[ "$SKIP" == *" $name "* ]]; then
		continue
	elif [[ "$FORCE" == *" $name "* ]] || ! unit_installed "$name" \
		|| [[ "$(cat "$RUNTIME_DIR/.units/$name.key")" != "$(unit_key "$name")" ]]; then
		if [[ -e "$RUNTIME_DIR/.units/$name.key" || -e "$RUNTIME_DIR/.units/$name.files" \
			|| -e "$RUNTIME_DIR/.units/$name.before" ]]; then
			remove_unit "$name"
		fi
	fi
done
for file in "$RUNTIME_DIR"/.units/*.files "$RUNTIME_DIR"/.units/*.before; do
	[[ -e "$file" ]] || continue
	name=$(basename "${file%.*}")
	if ! is_unit "$name" && [[ -e "$file" ]]; then
		remove_unit "$name"
	fi
done

i=0
for name in "${UNITS[@]}"; do
	i=$((i + 1))
	key=$(unit_key "$name")
	header "Unit $i/${#UNITS[@]}: $name ($key)"
	if [[ "$SKIP" == *" $name "* ]]; then
		echo "Skipped."
		continue
	elif [[ -e "$RUNTIME_DIR/.units/$name.key" ]]; then
		echo "Up to date."
		continue
	fi

	if [[ "$RUNTIME_REPO" != "" && "$ORAS" != "" && "$RUNTIME_PULL" != false && "$FORCE" != *" $name "* ]] \
		&& runtime_oci unit-pull "$ARCHITECTURE" "$name" "$key" "$TEMPDIR/$name.tar.gz"; then
		unpack_unit "$name" "$TEMPDIR/$name.tar.gz"
	else
		build_unit "$name"
		if [[ "$RUNTIME_PUSH" == true ]]; then
			pack_unit "$name" "$TEMPDIR/$name.tar.gz"
			runtime_oci unit-push "$ARCHITECTURE" "$name" "$key" "$TEMPDIR/$name.tar.gz"
		fi
	fi
	echo "$key" > "$RUNTIME_DIR/.units/$name.key"
	rm -f "$TEMPDIR/$name.tar.gz"
done

header "Checking the architecture of the compiled libraries..."
find "$RUNTIME_DIR/lib" -type f -name '*.dylib' -print0 | xargs -0 file
find "$RUNTIME_DIR/lib" -type f -name '*.a' -print0 | xargs -0 -n 1 lipo -info
for file in $(find "$RUNTIME_DIR/lib" -type f \( -name '*.dylib' -o -name '*.a' \)); do
	if [[ " $(lipo -archs "$file") " != *" $ARCHITECTURE "* ]]; then
		error "$file is not built for $ARCHITECTURE"
		exit 1
	fi
done
header "All done!"
