#!/usr/bin/env bash
#
# Regenerates every provider distribution from the canonical sources.
#
#   workflows/  ->  commands/            (Claude slash commands)
#               ->  codex/skills/        (Codex skills)
#   experts/    ->  agents/              (Claude subagents)
#               ->  codex/skills/        (Codex skills)
#
# Everything this script writes is a build artifact: edit the canonical sources instead.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/render.sh
. "$repo_root/scripts/lib/render.sh"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

render_distributions "$repo_root" "$staging"

rm -rf "$repo_root/commands" "$repo_root/agents" "$repo_root/codex/skills" "$repo_root/codex/.codex-plugin"
mkdir -p "$repo_root/codex"
cp -R "$staging/commands" "$repo_root/commands"
cp -R "$staging/agents" "$repo_root/agents"
cp -R "$staging/codex/skills" "$repo_root/codex/skills"
cp -R "$staging/codex/.codex-plugin" "$repo_root/codex/.codex-plugin"

printf '✓ Generated %s commands, %s agents and %s Codex skills.\n' \
  "$(find "$repo_root/commands" -name '*.md' | wc -l | tr -d ' ')" \
  "$(find "$repo_root/agents" -name '*.md' | wc -l | tr -d ' ')" \
  "$(find "$repo_root/codex/skills" -name 'SKILL.md' | wc -l | tr -d ' ')"
