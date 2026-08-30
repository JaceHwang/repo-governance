#!/bin/sh
set -eu

source_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
codex_root=${CODEX_HOME:-$HOME/.codex}
destination="$codex_root/skills/repository-governance"

mkdir -p "$destination/agents"
cp "$source_root/skill/repository-governance/SKILL.md" "$destination/SKILL.md"
cp "$source_root/skill/repository-governance/agents/openai.yaml" "$destination/agents/openai.yaml"
printf 'skill=repository-governance path=%s\n' "$destination"
