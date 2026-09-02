#!/usr/bin/env bash
#
# Fails when the committed distributions no longer match the canonical sources.
#
# Renders workflows/ and experts/ into a temporary tree and diffs it against
# commands/, agents/ and codex/. Run ./scripts/generate-distributions.sh to fix.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/render.sh
. "$repo_root/scripts/lib/render.sh"

expected="$(mktemp -d)"
trap 'rm -rf "$expected"' EXIT

render_distributions "$repo_root" "$expected"

status=0
for target in commands agents codex/skills codex/.codex-plugin; do
  if [ ! -d "$repo_root/$target" ]; then
    printf '✗ Missing %s — run ./scripts/generate-distributions.sh.\n' "$target" >&2
    status=1
    continue
  fi
  if ! diff -ru "$expected/$target" "$repo_root/$target"; then
    printf '✗ %s is out of date with the canonical sources.\n' "$target" >&2
    status=1
  fi
done

if [ "$status" -ne 0 ]; then
  printf '\nRun ./scripts/generate-distributions.sh and commit the result.\n' >&2
  exit 1
fi

printf '✓ Claude and Codex distributions are in sync with workflows/ and experts/.\n'
