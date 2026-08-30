#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
sh "$project_root/tests/test-governance.sh"
sh "$project_root/tests/test-install.sh"
sh "$project_root/tests/test-project-release.sh"
sh "$project_root/tests/test-release-pr-state.sh"
sh "$project_root/tests/test-github-policy.sh"
