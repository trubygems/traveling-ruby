#!/bin/bash
# Updates the dependencies in image/deps, macos/deps and image/Dockerfile to
# their newest releases, with the new checksums, and prints a Markdown table
# of what changed (nothing when nothing did).
#
# A recipe's LATEST is '<page> <regex>': the newest release is the highest
# (?<version>...) that the Perl regex matches on the page, and other named
# groups set the recipe variable of the same name in upper case, such as YEAR
# for SQLite. Recipes without LATEST, such as libstdcxx, are left alone.
#
#   GITHUB_TOKEN   used for api.github.com, which limits anonymous requests
#   DRY_RUN=1      only print what would change
set -euo pipefail
cd "$(dirname "$0")/.."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
changes=()
# Gives up on a server that stops responding, rather than hanging the job
curl=(curl --fail -sSL --retry 3 --connect-timeout 30 --max-time 600)

# Prints the page at $1, downloading it once
function page()
{
	local file
	file="$work/page-$(printf '%s' "$1" | shasum -a 256 | cut -c1-16)"
	if [[ ! -f "$file" ]]; then
		local auth=()
		if [[ "$1" == https://api.github.com/* && -n "${GITHUB_TOKEN:-}" ]]; then
			auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
		fi
		"${curl[@]}" ${auth[@]+"${auth[@]}"} -o "$file" "$1"
	fi
	cat "$file"
}

# Prints the SHA-256 of the file at $1. Call it in an assignment, such as
# sum=$(sha256 ...), so that a failed download stops the script.
function sha256()
{
	"${curl[@]}" "$1" | shasum -a 256 | cut -d' ' -f1
}

# Prints the newest release that '<page> <regex>' finds, then each other named
# group as NAME=value
function newest()
{
	local url=${1%% *} regex=${1#* }
	page "$url" | RE="$regex" perl -0777 -ne '
		while (/$ENV{RE}/g) {
			print join(" ", $+{version}, map { uc($_) . "=$+{$_}" } grep { $_ ne "version" } sort keys %+), "\n";
		}' | sort -V | tail -1
}

# Succeeds when version $2 is newer than $1
function newer()
{
	[[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" == "$2" ]]
}

# Sets VAR=value ($2) on each line of file $1 that sets VAR, where VAR comes
# at the start of the line or after whitespace (as in a Dockerfile ARG)
function set_var()
{
	VAR=${2%%=*} VALUE=${2#*=} perl -pi -e \
		's/(^|\s)\Q$ENV{VAR}\E=\S+/$1$ENV{VAR}=$ENV{VALUE}/' "$1"
}

# Records a change for the table: name, old, new, release page
function changed()
{
	changes+=("| $1 | $2 | $3 | $4 |")
	echo "$1: $2 -> $3" >&2
}

# Recipes, grouped by NAME so that image/deps and macos/deps stay in step
done_names=" "
for recipe in image/deps/*.sh macos/deps/*.sh; do
	IFS='|' read -r name version latest < <(bash -c 'source "$1"; printf "%s|%s|%s\n" "$NAME" "$VERSION" "${LATEST:-}"' _ "$recipe")
	[[ -n "$latest" && "$done_names" != *" $name "* ]] || continue
	done_names+="$name "
	read -r new vars < <(newest "$latest") || true
	if [[ -z "${new:-}" ]]; then
		echo "$name: no release found on ${latest%% *}" >&2
		exit 1
	fi
	newer "$version" "$new" || continue
	changed "$name" "$version" "$new" "${latest%% *}"
	[[ -z "${DRY_RUN:-}" ]] || continue
	for file in image/deps/*.sh macos/deps/*.sh; do
		grep -qx "NAME=$name" "$file" || continue
		set_var "$file" "VERSION=$new"
		for var in $vars; do
			set_var "$file" "$var"
		done
		url=$(bash -c 'source "$1"; echo "$URL"' _ "$file")
		sum=$(sha256 "$url")
		set_var "$file" "SHA256=$sum"
	done
done

# The Dockerfile's CMake and ccache follow the macOS recipes
dockerfile=image/Dockerfile
function dockerfile_var()
{
	sed -n "s/.*[[:space:]]$1=\([^[:space:]]*\).*/\1/p" "$dockerfile" | head -1
}

old=$(dockerfile_var CMAKE_VERSION)
new=$(bash -c 'source macos/deps/cmake.sh; echo "$VERSION"')
if newer "$old" "$new"; then
	changed cmake "$old" "$new" "https://github.com/Kitware/CMake/releases"
	if [[ -z "${DRY_RUN:-}" ]]; then
		sum=$(sha256 "https://github.com/Kitware/CMake/releases/download/v$new/cmake-$new.tar.gz")
		set_var "$dockerfile" "CMAKE_VERSION=$new"
		set_var "$dockerfile" "CMAKE_SHA256=$sum"
	fi
fi

old=$(dockerfile_var CCACHE_VERSION)
new=$(bash -c 'source macos/deps/ccache.sh; echo "$VERSION"')
if newer "$old" "$new"; then
	changed ccache "$old" "$new" "https://github.com/ccache/ccache/releases"
	if [[ -z "${DRY_RUN:-}" ]]; then
		set_var "$dockerfile" "CCACHE_VERSION=$new"
		for arch in x86_64 aarch64; do
			file=ccache-$new-linux-$arch-musl-static.tar.xz
			sum=$(sha256 "https://github.com/ccache/ccache/releases/download/v$new/$file")
			set_var "$dockerfile" "$arch) sha=$sum"
		done
	fi
fi

old=$(dockerfile_var RUST_VERSION)
read -r new _ < <(newest 'https://static.rust-lang.org/dist/channel-rust-stable.toml \[pkg\.rust\]\s*version\s*=\s*"(?<version>\d+\.\d+\.\d+)')
if newer "$old" "$new"; then
	changed Rust "$old" "$new" "https://blog.rust-lang.org/releases/"
	[[ -n "${DRY_RUN:-}" ]] || set_var "$dockerfile" "RUST_VERSION=$new"
fi

old=$(dockerfile_var RUSTUP_VERSION)
read -r new _ < <(newest "https://static.rust-lang.org/rustup/release-stable.toml version\s*=\s*['\"](?<version>\d+\.\d+\.\d+)")
if newer "$old" "$new"; then
	changed rustup "$old" "$new" "https://github.com/rust-lang/rustup/releases"
	if [[ -z "${DRY_RUN:-}" ]]; then
		set_var "$dockerfile" "RUSTUP_VERSION=$new"
		for target in {x86_64,aarch64}-unknown-linux-{gnu,musl}; do
			sha=$(page "https://static.rust-lang.org/rustup/archive/$new/$target/rustup-init.sha256" | cut -d' ' -f1)
			set_var "$dockerfile" "$target) sha=$sha"
		done
	fi
fi

if [[ ${#changes[@]} -gt 0 ]]; then
	echo "| Dependency | From | To | Releases |"
	echo "| --- | --- | --- | --- |"
	printf '%s\n' "${changes[@]}"
fi
