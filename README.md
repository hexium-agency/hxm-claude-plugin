# Hexium Claude Code Plugin

A shared toolkit for the Hexium dev team: git workflows, documentation, code review and ticket
planning. The business procedures live once in this repository and are distributed to two agent
runtimes — **Claude Code** (production) and **Codex** (preparatory).

## Installation (Claude Code)

Add the marketplace (once), then install the plugin:

```shell
/plugin marketplace add hexium-agency/hxm-claude-plugin
/plugin install hxm@hexium-tools
```

To update manually, run `/plugin update` in Claude Code.

## Installation (Codex)

Codex has its own plugin system, and the flow mirrors Claude Code's:

```bash
codex plugin marketplace add hexium-agency/hxm-claude-plugin
codex plugin add hxm@hexium-tools
```

Skills are then invoked as `$hxm-commit`, `$hxm-rebase`, `$hxm-plan-ticket`, … or activate on their
description. The `hxm-` prefix is deliberate: Codex has a single flat skill namespace.
See [codex/README.md](codex/README.md) for local testing, prerequisites and the known limitations of
that distribution.

## Architecture: one source, two distributions

```
workflows/            # 16 canonical business procedures — provider-neutral
experts/              #  5 canonical domain expertises  — provider-neutral
bindings/claude/      # the only irreducible Claude-specific data (model, allowed-tools)
bindings/codex/       # Codex-only manifest metadata (the required `interface` block)
scripts/              # generation and validation harness
├── lib/render.sh
├── generate-distributions.sh
├── check-distributions.sh
└── check-version-consistency.sh

commands/             # GENERATED — Claude slash commands (/hxm:<name>)
agents/               # GENERATED — Claude subagents
codex/                # GENERATED — Codex plugin
├── .codex-plugin/plugin.json
└── skills/hxm-<name>/SKILL.md
.claude-plugin/       # Claude manifest + hexium-tools marketplace catalog
.agents/plugins/      # Codex marketplace catalog (hand-written, points at ./codex)
```

**Everything under `commands/`, `agents/` and `codex/` is generated. Never edit those files** — the
next generation run overwrites them and CI fails on drift. `codex/README.md` is the one hand-written
exception inside `codex/`.

### Canonical sources

A canonical file is a plain Markdown procedure with a provider-neutral frontmatter:

```yaml
---
name: rebase
description: Rebase the current branch onto its base — ...   # Claude command description
arguments: [<base-branch>] [--ci]                            # Claude argument-hint
trigger: Use when the user asks to rebase the current branch, ...  # Codex skill description
requires: none | clickup | figma | context7 | gh (comma-separated)
---
```

Two template mechanisms keep the body neutral:

- `{{command:review}}` renders as `/hxm:review` for Claude and `/review` for Codex.
- Provider blocks isolate what genuinely differs between runtimes:

  ```markdown
  <!-- provider:claude -->
  1. Use the Task tool with `subagent_type=Explore` to:

  <!-- /provider -->
  <!-- provider:codex -->
  1. Explore the codebase yourself (targeted greps and reads) to:

  <!-- /provider -->
  ```

  Author each block as a complete paragraph unit (content ending with its blank line) so both renders
  read correctly. Markers may be indented to match the surrounding list.

### Why `bindings/claude/`

Claude's `allowed-tools` entries (`Bash(git push --force-with-lease:*)`, `mcp__clickup`, …) are a real
technical guard, not decoration, and no neutral abstraction expresses them without losing behaviour.
Rather than degrade the existing commands, they stay as an explicit per-provider binding file
alongside `model`. Codex needs no equivalent: its skills only take `name` + `description`, both
derived from the canonical frontmatter.

## Modifying a workflow

1. Edit `workflows/<name>.md` (or `experts/<name>.md`) — never the generated output.
2. If the change touches Claude tool permissions or the model, edit `bindings/claude/commands.json`
   (or `agents.json`).
3. Regenerate and validate:

   ```bash
   ./scripts/generate-distributions.sh
   ./scripts/check-distributions.sh
   ```

4. Commit the canonical source **and** the regenerated artifacts together.

Adding a workflow is the same flow: create `workflows/<name>.md`, add its binding entry, regenerate.
The generator fails loudly if a binding or a `trigger` is missing.

The harness needs only `bash`, `awk`, `sed` and `jq` — the same dependencies the repository already
had.

## Testing locally

**Claude Code:**

```bash
claude --plugin-dir ./hxm-claude-plugin
```

Then run any `/hxm:<command>`. Both distributions can be tested side by side: the Claude plugin stays
installable from the repository root while Codex is exercised from `codex/`.

**Codex:** see [codex/README.md](codex/README.md).

## Releasing

Run `/hxm:bump` to bump `.claude-plugin/plugin.json`, regenerate the distributions and create the
matching git tag, then `git push && git push --tags`. Users only receive an update when that version
string changes.

The version is declared in `plugin.json` only — the marketplace entry deliberately omits it, since
Claude Code reads `plugin.json` first and would silently ignore a marketplace value. The Codex
manifest is generated from `plugin.json`, so it can never drift. CI enforces both; run the same
checks locally with:

```bash
./scripts/check-version-consistency.sh
./scripts/check-distributions.sh
```

The Codex plugin can also be checked against the official schema with the validator shipped by Codex:

```bash
python3 ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py ./codex
```

## Prerequisites

- [Claude Code](https://code.claude.com) CLI
- `jq` (generation and validation scripts)
- A ClickUp MCP server, for the ticket commands: `/hxm:plan-ticket`, `/hxm:estimate-ticket`,
  `/hxm:spec-ticket`, `/hxm:wrap-up`, `/hxm:handle-feedback`
- A Figma MCP server, for `/hxm:spec-ticket`
- A Context7 MCP server, for the `context7-expert` agent
- The GitHub CLI (`gh`), authenticated, for `/hxm:create-pr` and `/hxm:handle-feedback`

No credentials or MCP configuration are shipped with this plugin.

## Contributing

See [CLAUDE.md](CLAUDE.md) for development guidelines.

## License

[MIT](LICENSE)
