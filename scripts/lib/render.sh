#!/usr/bin/env bash
#
# Shared rendering engine for the hxm distributions.
#
# Canonical sources live in workflows/ and experts/. Everything under commands/,
# agents/ and codex/ is generated from them and must never be edited by hand.
#
# Sourced by scripts/generate-distributions.sh and scripts/check-distributions.sh.

set -euo pipefail

render_fail() {
  printf '✗ %s\n' "$1" >&2
  exit 1
}

# Extracts the raw value of a canonical frontmatter key.
render_fm_value() { # <file> <key>
  awk -v k="$2" '
    NR == 1 && $0 == "---" { inside = 1; next }
    inside && $0 == "---" { exit }
    inside && index($0, k ": ") == 1 { print substr($0, length(k) + 3) }
  ' "$1"
}

# Line number of the first body line (the line following the closing "---").
render_body_start() { # <file>
  awk '
    NR == 1 && $0 == "---" { inside = 1; next }
    inside && $0 == "---" { print NR + 1; exit }
  ' "$1"
}

# Emits the canonical body rendered for one provider:
#   - keeps only the <!-- provider:<name> --> blocks addressed to that provider
#   - expands {{command:<name>}} into the provider's invocation syntax
render_body() { # <file> <provider>
  local file="$1" provider="$2" start
  start="$(render_body_start "$file")"
  [ -n "$start" ] || render_fail "$file has no closing frontmatter delimiter."

  local expansion
  case "$provider" in
    claude) expansion='/hxm:\1' ;;
    codex) expansion="\$${RENDER_CODEX_PREFIX:-hxm-}\\1" ;;
    *) render_fail "Unknown provider \"$provider\"." ;;
  esac

  tail -n "+$start" "$file" \
    | awk -v provider="$provider" '
        /^[[:space:]]*<!-- provider:[a-z]+ -->[[:space:]]*$/ {
          match($0, /provider:[a-z]+/)
          block = 1
          keep = (substr($0, RSTART + 9, RLENGTH - 9) == provider)
          next
        }
        /^[[:space:]]*<!-- \/provider -->[[:space:]]*$/ { block = 0; next }
        { if (!block || keep) print }
      ' \
    | sed -E "s#\{\{command:([a-z0-9-]+)\}\}#${expansion}#g"
}

# Human-readable prerequisite line for one `requires` token.
render_requirement() { # <token>
  case "$1" in
    clickup) printf -- '- **ClickUp MCP server** — ticket lookup, comments and metadata. Without it, the skill falls back to details pasted by the user.\n' ;;
    context7) printf -- '- **Context7 MCP server** — up-to-date library documentation.\n' ;;
    figma) printf -- '- **Figma MCP server** — design context, screenshots and metadata. Without it, the design check is reported as skipped.\n' ;;
    gh) printf -- '- **GitHub CLI (`gh`)**, authenticated against the repository remote.\n' ;;
    *) render_fail "Unknown requirement token \"$1\"." ;;
  esac
}

render_requirements_section() { # <requires-value>
  local requires="$1" token
  [ "$requires" = "none" ] && return 0

  printf '\n## Prerequisites\n\n'
  local IFS=','
  for token in $requires; do
    token="${token//[[:space:]]/}"
    [ -n "$token" ] || continue
    render_requirement "$token"
  done
  printf '\nConfigure these as MCP servers in your own Codex configuration. This plugin ships no credentials\nand no MCP configuration.\n'
}

# Renders one canonical workflow into its Claude slash command.
render_claude_command() { # <workflow-file> <out-root> <bindings>
  local file="$1" out_root="$2" bindings="$3" name description arguments model tools
  name="$(render_fm_value "$file" name)"
  description="$(render_fm_value "$file" description)"
  arguments="$(render_fm_value "$file" arguments)"

  jq -e --arg n "$name" 'has($n)' "$bindings" >/dev/null \
    || render_fail "No Claude binding declared for command \"$name\" in $bindings."

  model="$(jq -r --arg n "$name" '.[$n].model' "$bindings")"
  tools="$(jq -r --arg n "$name" '.[$n]["allowed-tools"] | join(", ")' "$bindings")"

  mkdir -p "$out_root/commands"
  {
    printf -- '---\n'
    printf 'description: %s\n' "$description"
    printf 'argument-hint: %s\n' "$arguments"
    printf 'allowed-tools: [%s]\n' "$tools"
    printf 'model: %s\n' "$model"
    printf -- '---\n'
    render_body "$file" claude
  } > "$out_root/commands/$name.md"
}

# Renders one canonical expert into its Claude subagent.
render_claude_agent() { # <expert-file> <out-root> <bindings>
  local file="$1" out_root="$2" bindings="$3" name description tools
  name="$(render_fm_value "$file" name)"
  description="$(render_fm_value "$file" description)"

  jq -e --arg n "$name" 'has($n)' "$bindings" >/dev/null \
    || render_fail "No Claude binding declared for agent \"$name\" in $bindings."

  tools="$(jq -r --arg n "$name" '.[$n].tools' "$bindings")"

  mkdir -p "$out_root/agents"
  {
    printf -- '---\n'
    printf 'name: %s\n' "$name"
    printf 'description: %s\n' "$description"
    printf 'tools: %s\n' "$tools"
    printf -- '---\n'
    render_body "$file" claude
  } > "$out_root/agents/$name.md"
}

# Renders one canonical source into its Codex skill.
#
# Codex resolves skills in a single flat `$name` namespace shared by every installed
# plugin, so skill names carry the plugin prefix to avoid collisions — the equivalent
# of Claude's `/hxm:` command scoping.
render_codex_skill() { # <file> <out-root> <guardrails>
  local file="$1" out_root="$2" guardrails="$3" name skill_name trigger requires
  name="$(render_fm_value "$file" name)"
  trigger="$(render_fm_value "$file" trigger)"
  requires="$(render_fm_value "$file" requires)"
  [ -n "$trigger" ] || render_fail "$file declares no \"trigger\" — Codex skills need an activation description."
  [ "$trigger" != "TODO" ] || render_fail "$file still declares the placeholder trigger."
  case "$trigger" in
    *": "*) render_fail "$file trigger contains \": \" — it would break the generated YAML frontmatter." ;;
  esac
  [ -n "$requires" ] || requires="none"

  skill_name="${RENDER_CODEX_PREFIX:-hxm-}$name"

  mkdir -p "$out_root/codex/skills/$skill_name"
  {
    printf -- '---\n'
    printf 'name: %s\n' "$skill_name"
    printf 'description: %s\n' "$trigger"
    printf -- '---\n'
    render_body "$file" codex
    render_requirements_section "$requires"
    printf '\n'
    cat "$guardrails"
  } > "$out_root/codex/skills/$skill_name/SKILL.md"
}

# Derives the Codex manifest from the Claude manifest so both stay in lockstep,
# overlaid with the Codex-only presentation metadata the Codex schema requires.
#
# The accepted field set is enforced by Codex plugin validation: unknown top-level
# keys (including `hooks`) are rejected, and `interface` is mandatory.
render_codex_manifest() { # <out-root> <claude-manifest> <codex-overlay>
  local out_root="$1" manifest="$2" overlay="$3"
  mkdir -p "$out_root/codex/.codex-plugin"
  jq -S --slurpfile overlay "$overlay" '{
    name: .name,
    version: .version,
    description: .description,
    author: .author,
    homepage: .repository,
    repository: .repository,
    license: .license,
    keywords: .keywords
  } + $overlay[0]' "$manifest" > "$out_root/codex/.codex-plugin/plugin.json"
}

# Renders every distribution into <out-root>.
render_distributions() { # <repo-root> <out-root>
  local repo_root="$1" out_root="$2" file
  local command_bindings="$repo_root/bindings/claude/commands.json"
  local agent_bindings="$repo_root/bindings/claude/agents.json"
  local codex_overlay="$repo_root/bindings/codex/plugin.json"
  local guardrails="$repo_root/scripts/templates/codex-guardrails.md"

  command -v jq >/dev/null 2>&1 || render_fail "jq is required but not installed."
  [ -f "$repo_root/.claude-plugin/plugin.json" ] || render_fail "Missing $repo_root/.claude-plugin/plugin.json."

  # Codex skill namespace prefix, derived from the plugin name so the two never drift.
  RENDER_CODEX_PREFIX="$(jq -r '.name' "$repo_root/.claude-plugin/plugin.json")-"
  [ -d "$repo_root/workflows" ] || render_fail "Missing $repo_root/workflows."
  [ -d "$repo_root/experts" ] || render_fail "Missing $repo_root/experts."
  [ -f "$command_bindings" ] || render_fail "Missing $command_bindings."
  [ -f "$agent_bindings" ] || render_fail "Missing $agent_bindings."
  [ -f "$codex_overlay" ] || render_fail "Missing $codex_overlay."
  [ -f "$guardrails" ] || render_fail "Missing $guardrails."

  for file in "$repo_root"/workflows/*.md; do
    render_claude_command "$file" "$out_root" "$command_bindings"
    render_codex_skill "$file" "$out_root" "$guardrails"
  done

  for file in "$repo_root"/experts/*.md; do
    render_claude_agent "$file" "$out_root" "$agent_bindings"
    render_codex_skill "$file" "$out_root" "$guardrails"
  done

  render_codex_manifest "$out_root" "$repo_root/.claude-plugin/plugin.json" "$codex_overlay"
}
