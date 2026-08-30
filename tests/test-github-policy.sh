#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
output=$(mktemp -d "${TMPDIR:-/tmp}/repo-governance-policy.XXXXXX")
trap 'rm -rf "$output"' EXIT HUP INT TERM

"$project_root/scripts/configure-github.sh" --repo Example/project --dry-run "$output"

python3 - "$output" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
settings = json.loads((root / "repository-settings.json").read_text())
assert settings["allow_squash_merge"] is True
assert settings["allow_merge_commit"] is False
assert settings["allow_rebase_merge"] is False
assert settings["delete_branch_on_merge"] is True

main = json.loads((root / "main-ruleset.json").read_text())
assert main["target"] == "branch"
assert main["conditions"]["ref_name"]["include"] == ["~DEFAULT_BRANCH"]
rules = {rule["type"]: rule for rule in main["rules"]}
assert {"deletion", "non_fast_forward", "required_linear_history", "pull_request", "required_status_checks"} <= rules.keys()
assert rules["pull_request"]["parameters"]["required_approving_review_count"] == 0
contexts = {item["context"] for item in rules["required_status_checks"]["parameters"]["required_status_checks"]}
assert contexts == {"governance / policy", "verify / project"}

tags = json.loads((root / "tag-ruleset.json").read_text())
assert tags["target"] == "tag"
assert tags["conditions"]["ref_name"]["include"] == ["refs/tags/v*"]
assert {rule["type"] for rule in tags["rules"]} == {"deletion", "non_fast_forward"}
PY

printf 'PASS: GitHub repository policy payloads\n'

