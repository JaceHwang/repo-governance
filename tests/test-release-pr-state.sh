#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/repo-governance-release-pr.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM

cp -R "$project_root/." "$fixture/"
rm -rf "$fixture/.git" "$fixture/.dist" "$fixture/.project-board"
git -C "$fixture" init -q -b main
git -C "$fixture" config user.name Test
git -C "$fixture" config user.email test@example.com
git -C "$fixture" add .
git -C "$fixture" commit -q -m 'test: create release PR fixture'

printf '{\n  ".": "1.0.0"\n}\n' >"$fixture/.release-please-manifest.json"
printf '1.0.0\n' >"$fixture/version.txt"
git -C "$fixture" add .release-please-manifest.json version.txt
git -C "$fixture" commit -q -m 'chore(main): release 1.0.0'

cd "$fixture"
./governance check all

printf 'PASS: governance accepts a Release Please version state\n'
