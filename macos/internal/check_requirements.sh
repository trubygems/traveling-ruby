#!/bin/bash

set -e

if ! xcrun --show-sdk-path > /dev/null; then
	echo "*** ERROR: no macOS SDK found. Install Xcode or the Command Line Tools" \
		"and select it with xcode-select." >&2
	exit 1
fi

if [[ -e /usr/local/include ]]; then
	echo "*** ERROR: /usr/local/include exists, which may pollute the" \
		"build environment. Please temporarily rename it away:" >&2
	echo >&2
	echo "    rake stash_conflicting_paths" >&2
	exit 1
fi

if [[ -e /usr/local/lib ]]; then
	echo "*** ERROR: /usr/local/lib exists, which may pollute the" \
		"build environment. Please temporarily rename it away:" >&2
	echo >&2
	echo "    rake stash_conflicting_paths" >&2
	exit 1
fi
