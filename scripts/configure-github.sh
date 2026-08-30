#!/bin/sh
set -eu

repository=
mode=
output=

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) [ "$#" -ge 2 ] || exit 64; repository=$2; shift 2 ;;
    --dry-run) [ "$#" -ge 2 ] || exit 64; mode=dry-run; output=$2; shift 2 ;;
    --apply) mode=apply; shift ;;
    *) printf 'usage: configure-github.sh --repo OWNER/REPO (--dry-run DIR | --apply)\n' >&2; exit 64 ;;
  esac
done

printf '%s\n' "$repository" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' || {
  printf 'configure-github.sh: invalid --repo value\n' >&2
  exit 64
}
[ -n "$mode" ] || { printf 'configure-github.sh: choose --dry-run or --apply\n' >&2; exit 64; }

cleanup=0
if [ "$mode" = apply ]; then
  output=$(mktemp -d "${TMPDIR:-/tmp}/repo-governance-github.XXXXXX")
  cleanup=1
else
  mkdir -p "$output"
fi
if [ "$cleanup" -eq 1 ]; then
  trap 'rm -rf "$output"' EXIT HUP INT TERM
fi

cat >"$output/repository-settings.json" <<'JSON'
{
  "allow_squash_merge": true,
  "allow_merge_commit": false,
  "allow_rebase_merge": false,
  "delete_branch_on_merge": true
}
JSON

cat >"$output/main-ruleset.json" <<'JSON'
{
  "name": "Repository governance: main",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "required_linear_history"},
    {
      "type": "pull_request",
      "parameters": {
        "allowed_merge_methods": ["squash"],
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_approving_review_count": 0,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "do_not_enforce_on_create": true,
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          {"context": "governance / policy"},
          {"context": "verify / project"}
        ]
      }
    }
  ]
}
JSON

cat >"$output/tag-ruleset.json" <<'JSON'
{
  "name": "Repository governance: immutable version tags",
  "target": "tag",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {
      "include": ["refs/tags/v*"],
      "exclude": []
    }
  },
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"}
  ]
}
JSON

if [ "$mode" = dry-run ]; then
  printf 'mode=dry-run repository=%s output=%s\n' "$repository" "$output"
  exit 0
fi

command -v gh >/dev/null 2>&1 || { printf 'GitHub CLI is required\n' >&2; exit 69; }
visibility=$(gh repo view "$repository" --json isPrivate --jq '.isPrivate')
if [ "$visibility" = true ]; then
  printf 'remote-enforcement=unavailable visibility=private repository=%s\n' "$repository" >&2
  exit 3
fi

gh api -X PATCH "repos/$repository" --input "$output/repository-settings.json" >/dev/null

upsert_ruleset() {
  name=$1
  payload=$2
  case "$name" in
    main) query='.[] | select(.name == "Repository governance: main") | .id' ;;
    tags) query='.[] | select(.name == "Repository governance: immutable version tags") | .id' ;;
    *) exit 64 ;;
  esac
  id=$(gh api "repos/$repository/rulesets" --jq "$query" | head -n 1)
  if [ -n "$id" ]; then
    gh api -X PUT "repos/$repository/rulesets/$id" --input "$payload" >/dev/null
  else
    gh api -X POST "repos/$repository/rulesets" --input "$payload" >/dev/null
  fi
}

upsert_ruleset main "$output/main-ruleset.json"
upsert_ruleset tags "$output/tag-ruleset.json"
printf 'remote-enforcement=active repository=%s\n' "$repository"
