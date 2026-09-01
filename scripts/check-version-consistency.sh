#!/usr/bin/env bash
#
# Verifies that the plugin version is identical across every source of truth:
#
#   .claude-plugin/plugin.json  ==  marketplace entry version (only if declared)
#                              ==  codex/.codex-plugin/plugin.json (only if present)
#                              ==  latest git tag
#
# The marketplace entry is expected NOT to declare a version: Claude Code resolves
# the version from plugin.json first and silently ignores the marketplace value, so
# duplicating it only creates drift. The check therefore treats a marketplace version
# as optional, but enforces equality when one is present.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin_manifest="$repo_root/.claude-plugin/plugin.json"
marketplace_manifest="$repo_root/.claude-plugin/marketplace.json"
semver_pattern='^[0-9]+\.[0-9]+\.[0-9]+$'

fail() {
  printf '✗ %s\n' "$1" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required but not installed."
[ -f "$plugin_manifest" ] || fail "Missing $plugin_manifest — not a Claude Code plugin repository."

plugin_name="$(jq -r '.name // empty' "$plugin_manifest")"
plugin_version="$(jq -r '.version // empty' "$plugin_manifest")"

[ -n "$plugin_name" ] || fail "plugin.json declares no \"name\"."
[ -n "$plugin_version" ] || fail "plugin.json declares no \"version\"."
[[ "$plugin_version" =~ $semver_pattern ]] \
  || fail "plugin.json version \"$plugin_version\" is not a MAJOR.MINOR.PATCH semver string."

if [ -f "$marketplace_manifest" ]; then
  entry_count="$(jq --arg name "$plugin_name" '[.plugins[]? | select(.name == $name)] | length' "$marketplace_manifest")"

  case "$entry_count" in
    0) fail "No \"$plugin_name\" entry found in marketplace.json." ;;
    1) ;;
    *) fail "marketplace.json declares $entry_count entries named \"$plugin_name\"." ;;
  esac

  marketplace_version="$(jq -r --arg name "$plugin_name" \
    '.plugins[] | select(.name == $name) | .version // empty' "$marketplace_manifest")"

  if [ -n "$marketplace_version" ] && [ "$marketplace_version" != "$plugin_version" ]; then
    fail "Version mismatch: plugin.json is $plugin_version but the \"$plugin_name\" marketplace entry is $marketplace_version."
  fi
fi

codex_manifest="$repo_root/codex/.codex-plugin/plugin.json"

if [ -f "$codex_manifest" ]; then
  codex_version="$(jq -r '.version // empty' "$codex_manifest")"

  [ -n "$codex_version" ] || fail "codex/.codex-plugin/plugin.json declares no \"version\"."

  if [ "$codex_version" != "$plugin_version" ]; then
    fail "Version mismatch: plugin.json is $plugin_version but the Codex manifest is $codex_version. Run ./scripts/generate-distributions.sh."
  fi
fi

git rev-parse --git-dir >/dev/null 2>&1 || fail "Not a git repository — cannot compare against the latest tag."

latest_tag="$(git tag --list --sort=-v:refname | head -n 1)"
[ -n "$latest_tag" ] || fail "No git tag found — tag the current version with \"git tag $plugin_version\"."

latest_tag_version="${latest_tag#v}"

if [ "$latest_tag_version" != "$plugin_version" ]; then
  fail "Version mismatch: plugin.json is $plugin_version but the latest git tag is $latest_tag."
fi

checked="plugin.json"
if [ -n "${marketplace_version:-}" ]; then
  checked="$checked, the marketplace entry"
fi
if [ -n "${codex_version:-}" ]; then
  checked="$checked, the Codex manifest"
fi

printf '✓ Version %s is consistent across %s and the git tag %s.\n' "$plugin_version" "$checked" "$latest_tag"
