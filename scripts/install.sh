#!/bin/sh
set -eu

source_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
target=
mode=install

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target) [ "$#" -ge 2 ] || exit 64; target=$2; shift 2 ;;
    --update) mode=update; shift ;;
    *) printf 'usage: install.sh --target <git-repository> [--update]\n' >&2; exit 64 ;;
  esac
done

[ -n "$target" ] || { printf 'install.sh: --target is required\n' >&2; exit 64; }
target=$(CDPATH= cd -- "$target" && pwd)
git -C "$target" rev-parse --git-dir >/dev/null 2>&1 || {
  printf 'install.sh: target is not a Git repository: %s\n' "$target" >&2
  exit 64
}

install_file() {
  relative=$1
  destination="$target/$relative"
  mkdir -p "$(dirname "$destination")"
  cp "$source_root/$relative" "$destination"
}

install_if_missing() {
  relative=$1
  [ -e "$target/$relative" ] || install_file "$relative"
}

install_policy_if_missing() {
  [ -e "$target/.governance/policy.sh" ] && return
  mkdir -p "$target/.governance"
  cp "$source_root/templates/policy.sh" "$target/.governance/policy.sh"
}

install_agents_rules() {
  agents="$target/AGENTS.md"
  template="$source_root/templates/AGENTS-governance.md"
  if [ ! -f "$agents" ]; then
    cp "$template" "$agents"
    return
  fi
  tmp="${agents}.governance.$$"
  if grep -Fq '<!-- repo-governance:start -->' "$agents"; then
    awk '/<!-- repo-governance:start -->/{exit} {print}' "$agents" >"$tmp"
    cat "$template" >>"$tmp"
    awk 'found {print} /<!-- repo-governance:end -->/{found=1}' "$agents" >>"$tmp"
  else
    cp "$agents" "$tmp"
    [ -z "$(tail -n 1 "$tmp")" ] || printf '\n' >>"$tmp"
    cat "$template" >>"$tmp"
  fi
  mv "$tmp" "$agents"
}

for relative in \
  governance \
  .governance/VERSION \
  .governance/policy.defaults.sh \
  .githooks/pre-commit \
  .githooks/commit-msg \
  .githooks/pre-push \
  .github/workflows/governance.yml \
  .github/workflows/release-please.yml \
  .github/workflows/publish-platform.yml \
  .github/workflows/prerelease.yml
do
  install_file "$relative"
done

install_policy_if_missing

for relative in \
  .governance/adapters/format-staged \
  .governance/adapters/check-fast \
  .governance/adapters/check-full \
  .governance/adapters/build-release \
  .governance/adapters/verify-release \
  .governance/release/alpha.json \
  .governance/release/beta.json \
  .governance/release/rc.json \
  release-please-config.json \
  .release-please-manifest.json \
  version.txt
do
  install_if_missing "$relative"
done

chmod +x "$target/governance" "$target"/.githooks/* "$target"/.governance/adapters/*
install_agents_rules
printf 'governance=%s template=%s target=%s\n' "$mode" "$(cat "$source_root/.governance/VERSION")" "$target"
printf 'next=./governance bootstrap && ./governance doctor\n'
