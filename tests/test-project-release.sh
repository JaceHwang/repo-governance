#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/repo-governance-release.XXXXXX")
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
cp -R "$project_root/." "$fixture/"
rm -rf "$fixture/.git" "$fixture/.dist" "$fixture/.project-board"
git -C "$fixture" init -q -b main
git -C "$fixture" config user.name Test
git -C "$fixture" config user.email test@example.com
git -C "$fixture" add .
git -C "$fixture" commit -q -m 'test: create release fixture'
cd "$fixture"

.governance/project/build-release source v0.0.0
.governance/project/verify-release source v0.0.0

test -f .dist/release/repo-governance-v0.0.0.tar.gz
test -f .dist/release/SHA256SUMS.txt
test -f .dist/release/PROVENANCE.json
python3 -c '
import json
from pathlib import Path
data = json.loads(Path(".dist/release/PROVENANCE.json").read_text())
assert data["version"] == "0.0.0"
assert len(data["sourceCommit"]) == 40
'

printf 'PASS: repository governance release package\n'
