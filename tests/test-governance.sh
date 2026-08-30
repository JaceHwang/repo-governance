#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
governance_source="$project_root/governance"
failures=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

assert_eq() {
  expected=$1
  actual=$2
  label=$3
  [ "$expected" = "$actual" ] || fail "$label (expected '$expected', got '$actual')"
}

assert_fails() {
  label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$label (command unexpectedly succeeded)"
  fi
}

new_repo() {
  fixture=$(mktemp -d "${TMPDIR:-/tmp}/repo-governance-test.XXXXXX")
  git -C "$fixture" init -q -b main
  git -C "$fixture" config user.name Test
  git -C "$fixture" config user.email test@example.com
  cp "$governance_source" "$fixture/governance"
  cp -R "$project_root/.governance" "$fixture/.governance"
  cp -R "$project_root/.githooks" "$fixture/.githooks"
  : >"$fixture/.governance/policy.sh"
  chmod +x "$fixture/governance" "$fixture"/.githooks/* "$fixture"/.governance/adapters/*
}

commit_file() {
  repo=$1
  message=$2
  printf '%s\n' "$message" >"$repo/file.txt"
  git -C "$repo" add file.txt
  git -C "$repo" commit -q -m "$message"
}

test_bootstrap_and_branch_policy() {
  new_repo
  "$fixture/governance" bootstrap >/dev/null
  assert_eq '.githooks' "$(git -C "$fixture" config --local core.hooksPath)" 'bootstrap installs tracked hooks'
  assert_fails 'main is not a development branch' "$fixture/governance" check branch main
  "$fixture/governance" check all >/dev/null || fail 'CI project verification can run on the default branch'
  "$fixture/governance" check branch codex/feat/add-policy >/dev/null || fail 'valid Codex branch is accepted'
  "$fixture/governance" check branch codex/prerelease/rc >/dev/null || fail 'prerelease branch is accepted'
  assert_fails 'invalid branch slug is rejected' "$fixture/governance" check branch codex/feat/Add_Policy
  rm -rf "$fixture"
}

test_commit_message_normalization_and_validation() {
  new_repo
  message_file="$fixture/message.txt"
  printf 'Fix(core): reject stale data.  \r\n\r\n' >"$message_file"
  "$fixture/governance" check message "$message_file" >/dev/null || fail 'safe message normalization succeeds'
  assert_eq 'fix(core): reject stale data' "$(cat "$message_file")" 'message is normalized in place'

  printf 'feat(core): add policy validation\n\nBREAKING CHANGE: replace the policy schema\n' >"$message_file"
  "$fixture/governance" check message "$message_file" >/dev/null || fail 'breaking footer is accepted'
  printf 'missing conventional prefix\n' >"$message_file"
  assert_fails 'missing type is rejected' "$fixture/governance" check message "$message_file"
  printf 'feat(Bad_Scope): add policy\n' >"$message_file"
  assert_fails 'invalid scope is rejected' "$fixture/governance" check message "$message_file"
  rm -rf "$fixture"
}

test_pr_title_validation() {
  new_repo
  "$fixture/governance" check title 'feat(release): add staged publishing' >/dev/null || fail 'valid PR title is accepted'
  assert_fails 'invalid PR title is rejected' "$fixture/governance" check title 'Add staged publishing'
  rm -rf "$fixture"
}

test_staged_check_protects_partial_changes_and_stops_after_formatting() {
  new_repo
  git -C "$fixture" switch -q -c codex/feat/staged-check
  printf 'base\n' >"$fixture/file.txt"
  git -C "$fixture" add file.txt
  git -C "$fixture" commit -q -m 'test: add fixture'

  printf 'staged\n' >"$fixture/file.txt"
  git -C "$fixture" add file.txt
  printf 'unstaged\n' >>"$fixture/file.txt"
  assert_fails 'partially staged files are rejected before formatting' "$fixture/governance" check staged

  git -C "$fixture" restore --worktree file.txt
  cat >"$fixture/.governance/adapters/format-staged" <<'EOF'
#!/bin/sh
printf 'formatted\n' >file.txt
EOF
  chmod +x "$fixture/.governance/adapters/format-staged"
  assert_fails 'formatter changes abort the commit for review' "$fixture/governance" check staged
  assert_eq 'formatted' "$(cat "$fixture/file.txt")" 'formatter correction is preserved for review'
  rm -rf "$fixture"
}

test_staged_check_preserves_unrelated_unstaged_work() {
  new_repo
  git -C "$fixture" switch -q -c codex/fix/preserve-worktree
  printf 'base\n' >"$fixture/file.txt"
  printf 'other base\n' >"$fixture/other.txt"
  git -C "$fixture" add file.txt other.txt
  git -C "$fixture" commit -q -m 'test: add fixture files'
  printf 'staged change\n' >"$fixture/file.txt"
  git -C "$fixture" add file.txt
  printf 'unrelated work\n' >"$fixture/other.txt"
  "$fixture/governance" check staged >/dev/null || fail 'unrelated unstaged work is preserved and accepted'
  assert_eq 'unrelated work' "$(cat "$fixture/other.txt")" 'unrelated unstaged work remains unchanged'
  rm -rf "$fixture"
}

test_commit_range_and_version_mapping() {
  new_repo
  git -C "$fixture" switch -q -c codex/feat/version-policy
  commit_file "$fixture" 'chore: establish baseline'
  base=$(git -C "$fixture" rev-parse HEAD)
  commit_file "$fixture" 'fix(core): reject malformed policy'
  head=$(git -C "$fixture" rev-parse HEAD)
  "$fixture/governance" check commits "$base" "$head" >/dev/null || fail 'valid commit range succeeds'
  assert_eq '0.3.6' "$("$fixture/governance" version next 0.3.5 "$base" "$head")" 'fix bumps patch'

  commit_file "$fixture" 'feat(core): add release units'
  head=$(git -C "$fixture" rev-parse HEAD)
  assert_eq '0.4.0' "$("$fixture/governance" version next 0.3.5 "$base" "$head")" 'pre-1.0 feature bumps minor'

  git -C "$fixture" commit --allow-empty -q -m 'feat(core)!: replace policy schema'
  head=$(git -C "$fixture" rev-parse HEAD)
  assert_eq '0.4.0' "$("$fixture/governance" version next 0.3.5 "$base" "$head")" 'pre-1.0 breaking change bumps minor'
  assert_eq '2.0.0' "$("$fixture/governance" version next 1.4.2 "$base" "$head")" 'stable breaking change bumps major'

  git -C "$fixture" commit --allow-empty -q -m 'docs: explain release flow'
  docs_base=$(git -C "$fixture" rev-parse HEAD~1)
  docs_head=$(git -C "$fixture" rev-parse HEAD)
  assert_eq 'none' "$("$fixture/governance" version next 1.4.2 "$docs_base" "$docs_head")" 'docs-only range does not release'

  git -C "$fixture" commit --allow-empty -q -m 'not conventional'
  invalid_head=$(git -C "$fixture" rev-parse HEAD)
  assert_fails 'invalid commit in range is rejected' "$fixture/governance" check commits "$docs_head" "$invalid_head"
  rm -rf "$fixture"
}

test_release_status_matrix_is_deterministic() {
  new_repo
  printf "RELEASE_PLATFORMS='macos-arm64 windows-x64'\n" >"$fixture/.governance/policy.sh"
  body="$fixture/release-body.md"
  printf '# Release v0.4.0\n\nRelease notes stay intact.\n' >"$body"
  "$fixture/governance" release status "$body" macos-arm64 available
  grep -Fq 'Release notes stay intact.' "$body" || fail 'release status preserves release notes'
  grep -Fq '| macos-arm64 | available |' "$body" || fail 'selected platform becomes available'
  grep -Fq '| windows-x64 | pending |' "$body" || fail 'other platform remains pending'
  "$fixture/governance" release status "$body" windows-x64 not-targeted
  assert_eq '1' "$(grep -Fc '<!-- governance-platform-status:start -->' "$body")" 'status matrix is replaced, not duplicated'
  grep -Fq '| windows-x64 | not-targeted |' "$body" || fail 'later platform status update is applied'
  assert_fails 'unknown platform is rejected' "$fixture/governance" release status "$body" linux-x64 available
  assert_fails 'unknown status is rejected' "$fixture/governance" release status "$body" macos-arm64 broken
  rm -rf "$fixture"
}

test_bootstrap_and_branch_policy
test_commit_message_normalization_and_validation
test_pr_title_validation
test_staged_check_protects_partial_changes_and_stops_after_formatting
test_staged_check_preserves_unrelated_unstaged_work
test_commit_range_and_version_mapping
test_release_status_matrix_is_deterministic

if [ "$failures" -ne 0 ]; then
  printf '%s test(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'PASS: repository governance behavior\n'
