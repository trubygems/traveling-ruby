#!/bin/bash
# Checks that every DLL imported by the executables, DLLs and extensions in a
# Windows build can be found where Windows looks for it: next to the importing
# file, in bin.real, in bin.real/ruby_builtin_dlls or the arch directory
# (lib/ruby/<version>/<arch>, both searched by RubyInstaller's ruby.exe), or in
# the Windows system directory.
#
# Usage: ./sanity-check.sh <BUILD DIR>
#
# OBJDUMP picks the objdump (GNU or LLVM) to read import tables with, and
# SYSTEM_DLL_DIR the directory holding the Windows system DLLs.
set -e
set -o pipefail

DIR="$1"
if [[ -z "$DIR" || ! -d "$DIR" ]]; then
	echo "Usage: ./sanity-check.sh <BUILD DIR>"
	exit 1
fi

if [[ -z "$OBJDUMP" ]]; then
	OBJDUMP=$(command -v objdump || command -v llvm-objdump || true)
fi
if [[ -z "$OBJDUMP" ]]; then
	echo "objdump not found, set OBJDUMP"
	exit 1
fi

if [[ -z "$SYSTEM_DLL_DIR" ]]; then
	SYSTEM_DLL_DIR="${SYSTEMROOT:-C:/Windows}/System32"
	if command -v cygpath >/dev/null; then
		SYSTEM_DLL_DIR=$(cygpath -u "$SYSTEM_DLL_DIR")
	fi
fi
if [[ ! -d "$SYSTEM_DLL_DIR" ]]; then
	echo "System DLL directory $SYSTEM_DLL_DIR not found, set SYSTEM_DLL_DIR"
	exit 1
fi

function lowercase()
{
	tr '[:upper:]' '[:lower:]'
}

# Gem build leftovers (ext, ports, vendor, tmp) are never loaded
FILES=$(find "$DIR" -type f -size +0 \( -iname '*.exe' -o -iname '*.dll' -o -iname '*.so' \) |
	grep -vE '/gems/[^/]+/gems/[^/]+/(ext|ports|vendor|tmp)/')
BIN_DLLS=$(ls "$DIR/bin.real" "$DIR/bin.real/ruby_builtin_dlls" "$DIR"/lib/ruby/[0-9]*/*-mingw* 2>/dev/null | lowercase)
SYSTEM_DLLS=$(ls "$SYSTEM_DLL_DIR" | lowercase)

ERROR=false
while IFS= read -r F; do
	if ! IMPORTS=$("$OBJDUMP" -p "$F" | sed -n 's/^[[:space:]]*DLL Name: //p' | tr -d '\r' | lowercase | sort -u); then
		echo "$F could not be read by $OBJDUMP"
		ERROR=true
		continue
	fi
	FOUND_DLLS=$(echo "$BIN_DLLS"; ls "$(dirname "$F")" | lowercase; echo "$SYSTEM_DLLS")
	MISSING=()
	for DLL in $IMPORTS; do
		# api-ms-win-* and ext-ms-* are API sets Windows resolves itself
		if [[ "$DLL" == api-ms-* || "$DLL" == ext-ms-* ]]; then
			continue
		fi
		if ! grep -qxF "$DLL" <<<"$FOUND_DLLS"; then
			MISSING+=("$DLL")
		fi
	done
	if [[ ${#MISSING[@]} -gt 0 ]]; then
		echo "$F imports DLLs that are not bundled:"
		echo "    ${MISSING[*]}"
		ERROR=true
	fi
done <<<"$FILES"

if $ERROR; then
	echo "Uh Oh."
	exit 1
else
	echo "All OK."
fi
