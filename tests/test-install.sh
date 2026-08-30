#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
target=$(mktemp -d "${TMPDIR:-/tmp}/repo-governance-install.XXXXXX")
trap 'rm -rf "$target"' EXIT HUP INT TERM

git -C "$target" init -q -b main
git -C "$target" config user.name Test
git -C "$target" config user.email test@example.com
printf '# Existing instructions\n\nKeep this repository rule.\n' >"$target/AGENTS.md"

"$project_root/scripts/install.sh" --target "$target"

for path in \
  governance \
  .governance/policy.sh \
  .governance/adapters/format-staged \
  .governance/adapters/check-fast \
  .governance/adapters/check-full \
  .githooks/pre-commit \
  .githooks/commit-msg \
  .githooks/pre-push \
  .github/workflows/governance.yml \
  .github/workflows/release-please.yml \
  .github/workflows/publish-platform.yml \
  .github/workflows/prerelease.yml \
  release-please-config.json \
  .governance/release/alpha.json \
  .governance/release/beta.json \
  .governance/release/rc.json \
  .release-please-manifest.json \
  version.txt
do
  [ -f "$target/$path" ] || { printf 'FAIL: installer omitted %s\n' "$path" >&2; exit 1; }
done

python3 -m json.tool "$target/release-please-config.json" >/dev/null
python3 -m json.tool "$target/.release-please-manifest.json" >/dev/null
grep -Fq 'Keep this repository rule.' "$target/AGENTS.md" || {
  printf 'FAIL: installer replaced existing AGENTS.md content\n' >&2
  exit 1
}
[ "$(grep -Fc '<!-- repo-governance:start -->' "$target/AGENTS.md")" = 1 ] || {
  printf 'FAIL: installer did not add one managed AGENTS.md block\n' >&2
  exit 1
}

"$target/governance" bootstrap >/dev/null
[ "$(git -C "$target" config --local core.hooksPath)" = .githooks ] || {
  printf 'FAIL: installed governance cannot bootstrap hooks\n' >&2
  exit 1
}

printf 'custom project verification\n' >"$target/.governance/adapters/check-full"
"$project_root/scripts/install.sh" --target "$target" --update
[ "$(cat "$target/.governance/adapters/check-full")" = 'custom project verification' ] || {
  printf 'FAIL: update overwrote a project adapter\n' >&2
  exit 1
}
[ "$(grep -Fc '<!-- repo-governance:start -->' "$target/AGENTS.md")" = 1 ] || {
  printf 'FAIL: update duplicated the managed AGENTS.md block\n' >&2
  exit 1
}

skill_home=$(mktemp -d "${TMPDIR:-/tmp}/repo-governance-skill.XXXXXX")
CODEX_HOME="$skill_home" "$project_root/scripts/install-codex-skill.sh" >/dev/null
[ -f "$skill_home/skills/repository-governance/SKILL.md" ] || {
  printf 'FAIL: Codex skill installer omitted SKILL.md\n' >&2
  exit 1
}

if find "$target/.github/workflows" -type f -name '*.yml' -exec grep -En 'uses: [^ ]+@v[0-9]' {} + | grep -q .; then
  printf 'FAIL: workflow action is pinned only to a mutable version tag\n' >&2
  exit 1
fi

printf 'PASS: governance distribution installs and updates safely\n'
