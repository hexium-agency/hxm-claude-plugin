# hxm Plugin — Development Guidelines

## Plugin Documentation

Official Claude Code plugin docs: https://code.claude.com/docs/plugins

## Project Structure

This repository is a **single source of truth for two distributions**: a Claude Code plugin at the
repository root, and a Codex plugin under `codex/`.

### Canonical sources — edit these

| Directory | Purpose | Format |
|-----------|---------|--------|
| `workflows/` | Business procedures, provider-neutral | `.md` with neutral frontmatter |
| `experts/` | Domain expertises, provider-neutral | `.md` with neutral frontmatter |
| `bindings/claude/` | Claude-only `model` and `allowed-tools` | `commands.json`, `agents.json` |
| `bindings/codex/` | Codex-only manifest metadata (required `interface` block) | `plugin.json` |
| `.agents/plugins/` | Codex marketplace catalog, points at `./codex` | `marketplace.json` |
| `scripts/` | Generation and validation harness | shell |

### Generated artifacts — never edit

| Directory | Generated from | Consumed by |
|-----------|----------------|-------------|
| `commands/` | `workflows/` + `bindings/claude/commands.json` | Claude Code (`/hxm:<name>`) |
| `agents/` | `experts/` + `bindings/claude/agents.json` | Claude Code subagents |
| `codex/skills/hxm-<name>/` | `workflows/` + `experts/` | Codex |
| `codex/.codex-plugin/plugin.json` | `.claude-plugin/plugin.json` | Codex |

`codex/README.md` is the only hand-written file inside `codex/`.

A change to a generated file is lost on the next `./scripts/generate-distributions.sh` and fails CI.
If a generated file looks wrong, fix its canonical source.

## Workflow

```bash
# 1. edit workflows/<name>.md, experts/<name>.md, or bindings/claude/*.json
./scripts/generate-distributions.sh   # 2. rebuild commands/, agents/, codex/
./scripts/check-distributions.sh      # 3. prove the tree is in sync
./scripts/check-version-consistency.sh

# optional: validate the Codex plugin against the schema Codex itself enforces
python3 ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py ./codex
```

Commit the canonical source and the regenerated artifacts in the same commit.

## Canonical Frontmatter

```yaml
---
name: <kebab-case, matches the filename>
description: <Claude command/agent description>
arguments: <Claude argument-hint>          # workflows only
trigger: <Codex activation description — precise, no ": " sequence>
requires: none | clickup, figma, context7, gh
---
```

`description` drives Claude, `trigger` drives Codex skill activation, `requires` generates the Codex
**Prerequisites** section. The generator refuses to build a source whose `trigger` is missing or still
`TODO`.

## Body Templating

- `{{command:<name>}}` → `/hxm:<name>` (Claude) / `$hxm-<name>` (Codex — Codex invokes skills with a
  `$` prefix, not a slash, in one flat namespace shared by every installed plugin). The prefix is
  derived from the plugin name in `.claude-plugin/plugin.json`. Never hardcode `/hxm:` in a canonical
  body.
- Provider blocks for genuinely runtime-specific instructions:

  ```markdown
  <!-- provider:claude -->
  Claude-specific paragraph, ending with its blank line.

  <!-- /provider -->
  <!-- provider:codex -->
  Codex equivalent, ending with its blank line.

  <!-- /provider -->
  ```

  Use these only for real primitive gaps (`Task`, `EnterPlanMode`/`ExitPlanMode`, `AskUserQuestion`,
  plan-mode guards). Anything expressible neutrally stays neutral. Markers may be indented to match
  the surrounding list.

## Guardrails

`scripts/templates/codex-guardrails.md` is appended to **every** Codex skill. It restates the
non-negotiables: no commit/push without explicit confirmation, no force-push outside
`--force-with-lease` in the rebase workflow, stop on an ambiguous parent branch, never post to ClickUp
or GitHub on the user's behalf, never expand the scope. Business guardrails that belong to one
procedure stay in that procedure's canonical body.

## Conventions

- **Language**: All code, comments, and documentation in English.
- **Naming**: kebab-case for all files and directories.
- **Paths**: Use `${CLAUDE_PLUGIN_ROOT}` for all intra-plugin path references — never hardcode absolute paths.
- **Sorting**: Sort keys and methods by visibility (public > protected > private), then alphabetically.
- **Secrets**: Never commit credentials or a personal MCP configuration. External dependencies are
  documented, never bundled.

## Git

- All commits via `/hxm:commit` or following its procedure (conventional commits).
- Never commit without explicit user confirmation.
