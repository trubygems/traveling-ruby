#!/bin/bash
# Updates the gems in shared/gemfiles/default/Gemfile.lock to their newest
# releases, then derives Gemfile.lock.win from it, and prints a Markdown summary
# of what changed (nothing when nothing did).
#
# Gemfile.lock.win is the same resolution with Gem.win_platform? true, which
# leaves out the gems that do not build on Windows. It is resolved from the new
# Gemfile.lock without --update, so the gems both share keep the same versions.
#
#   SKIP_UPDATE=1  only derive Gemfile.lock.win from the current Gemfile.lock
set -euo pipefail
cd "$(dirname "$0")/../shared/gemfiles/default"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [[ -z "${SKIP_UPDATE:-}" ]]; then
	BUNDLE_GEMFILE=Gemfile bundle lock --update >&2
fi

sed 's/Gem\.win_platform?/true/g' Gemfile > "$work/Gemfile"
cp Gemfile.lock "$work/Gemfile.lock"
(cd "$work" && BUNDLE_GEMFILE=Gemfile bundle lock >&2)
cp "$work/Gemfile.lock" Gemfile.lock.win

changes=$(git diff -U0 Gemfile.lock | grep '^[-+]    [a-z]' || true)
if [[ -n "$changes" ]]; then
	printf 'Gems:\n\n```diff\n%s\n```\n' "$changes"
fi
