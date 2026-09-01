# hxm — Codex distribution

**Generated artifact. Do not edit anything under this directory by hand.**

Everything here (`skills/`, `.codex-plugin/plugin.json`) is produced by
`../scripts/generate-distributions.sh` from the canonical sources in `../workflows/` and
`../experts/`. Edit those, regenerate, and commit the result.

## What it contains

| Path | Origin |
|------|--------|
| `skills/hxm-<workflow>/SKILL.md` | `workflows/<workflow>.md` — 16 business procedures |
| `skills/hxm-<expert>/SKILL.md` | `experts/<expert>.md` — 5 domain expertises |
| `.codex-plugin/plugin.json` | Derived from `.claude-plugin/plugin.json` (same version, always) |

Each skill carries a minimal `name` + `description` frontmatter, the business procedure itself, an
explicit **Prerequisites** section when it depends on an external MCP server or CLI, and a shared
**Guardrails** section.

## Installation

Codex has a full plugin system that mirrors Claude Code's. From a consumer machine:

```bash
codex plugin marketplace add hexium-agency/hxm-claude-plugin
codex plugin add hxm@hexium-tools
```

The marketplace catalog lives at `.agents/plugins/marketplace.json` in the repository root — that is
the file Codex reads when it is pointed at this repo, and it resolves the plugin to `./codex`.

## Testing locally

Point Codex at your working copy instead of the GitHub remote:

```bash
./scripts/generate-distributions.sh
codex plugin marketplace add "$(pwd)"
codex plugin add hxm@hexium-tools
codex plugin list
```

To iterate without touching your real Codex configuration, run the same commands with an isolated
home:

```bash
CODEX_HOME=/tmp/codex-test codex plugin marketplace add "$(pwd)"
CODEX_HOME=/tmp/codex-test codex plugin add hxm@hexium-tools
```

Validate the plugin against the official schema before publishing (the validator ships with Codex,
and needs `pyyaml`):

```bash
python3 ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py ./codex
```

## Invoking a skill

Skills activate on their `description`, so a natural-language request ("commit these changes",
"rebase this branch onto develop") is enough. To invoke one explicitly, Codex uses the `$` prefix:

```
$hxm-commit --all
$hxm-rebase develop --ci
```

That is the syntax used in the generated `## Usage` blocks — the Claude `/hxm:<name>` form is
rewritten to `$hxm-<name>` at generation time.

Skill names carry the `hxm-` prefix on purpose: Codex resolves every installed plugin's skills in one
flat `$name` namespace, so an unprefixed `$commit` or `$review` would collide with another plugin.
The prefix is derived from the plugin name in `.claude-plugin/plugin.json`, so the two cannot drift.

## Prerequisites

The plugin ships **no credentials and no MCP configuration**. Configure these yourself if you want
the skills that depend on them:

| Dependency | Needed by |
|------------|-----------|
| ClickUp MCP server | `hxm-plan-ticket`, `hxm-spec-ticket`, `hxm-estimate-ticket`, `hxm-wrap-up`, `hxm-handle-feedback` |
| Figma MCP server | `hxm-spec-ticket` |
| Context7 MCP server | `hxm-context7-expert` |
| GitHub CLI (`gh`), authenticated | `hxm-create-pr`, `hxm-handle-feedback` |

Every skill degrades gracefully: when a dependency is missing it reports the fact and continues
without that part of the analysis.

## Known limitations of this distribution

These are deliberate, and follow from Codex not having the Claude Code primitives one-to-one:

1. **No tool allowlist.** Claude commands declare `allowed-tools` (e.g. `Bash(git push --force-with-lease:*)`),
   which is a hard technical guard. Codex skills have no equivalent field, so the same guarantees are
   expressed as prose in each skill's **Guardrails** section. They are instructions, not sandboxing:
   review what a skill does before letting it run unattended.
2. **No per-skill model pinning.** Claude commands pin `haiku` / `sonnet` / `opus`. Codex skills run on
   whatever model the session uses.
3. **No subagents.** Where a Claude command delegates to `Task` with `subagent_type=Explore`
   (`hxm-plan-ticket`, `hxm-spec-ticket`, `hxm-wrap-up`), the Codex skill explores inline with
   targeted greps and reads. Slower on very large diffs, same output.
4. **No plan mode.** `EnterPlanMode` / `ExitPlanMode` (`hxm-plan-ticket`) and the "must not run in
   plan mode" guard (`hxm-commit`, `hxm-commit-atomic`, `hxm-bump`) have no Codex counterpart.
   `hxm-plan-ticket` states the read-only constraint explicitly instead; the plan-mode guards are
   simply dropped for Codex.
5. **No structured question widget.** `AskUserQuestion` becomes a plain-text question the skill must
   ask before continuing. The confirmation is still mandatory.
6. **The five experts are plain skills.** In Claude they are autonomous subagents with their own tool
   allowlist; in Codex they are knowledge modules the main agent reads.
7. **Namespacing is manual.** Claude scopes commands as `/hxm:commit` natively; Codex has one flat
   `$name` namespace, so the prefix is baked into the generated skill names instead.

The manifest itself is not a limitation: `.codex-plugin/plugin.json` is generated from
`.claude-plugin/plugin.json` plus the Codex-only presentation metadata in `bindings/codex/plugin.json`,
and it passes the official `validate_plugin.py` from the `plugin-creator` system skill.
