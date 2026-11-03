#!/bin/bash
# Replaces shared/ca-bundle.crt, the CA certificates every package ships with,
# with curl's extract of the Mozilla CA store (https://curl.se/docs/caextract.html),
# and prints the roots that were added and removed, as Markdown.
set -euo pipefail

cd "$(dirname "$0")/.."
bundle=shared/ca-bundle.crt
tmp=$(mktemp -d)
trap 'rm -f "$tmp"/*; rmdir "$tmp"' EXIT

curl -fsSL -o "$tmp/cacert.pem" https://curl.se/ca/cacert.pem
curl -fsSL -o "$tmp/cacert.pem.sha256" https://curl.se/ca/cacert.pem.sha256
(cd "$tmp" && sha256sum -c cacert.pem.sha256 >&2)

count=$(grep -c "BEGIN CERTIFICATE" "$tmp/cacert.pem")
if (( count < 100 )); then
	echo "Only $count certificates in cacert.pem" >&2
	exit 1
fi

# Root names: curl's format underlines each one with =, the older one put it
# in a # comment
function names()
{
	awk '/^=+$/ { print prev } /^# [^:]+$/ && !/^##/ { sub(/^# /, ""); print } { prev = $0 }' "$1" | sort
}
names "$bundle" > "$tmp/old"
names "$tmp/cacert.pem" > "$tmp/new"
cp "$tmp/cacert.pem" "$bundle"

echo "$(sed -n 's/^## Certificate data from Mozilla as of: //p' "$bundle"), $count certificates."
for change in Added Removed; do
	if [[ $change == Added ]]; then
		list=$(comm -13 "$tmp/old" "$tmp/new")
	else
		list=$(comm -23 "$tmp/old" "$tmp/new")
	fi
	if [[ -n "$list" ]]; then
		echo
		echo "$change:"
		echo
		sed 's/^/- /' <<< "$list"
	fi
done
