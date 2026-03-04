# hxm Plugin — Development Guidelines

## Plugin Documentation

Official Claude Code plugin docs: https://code.claude.com/docs/plugins

## Project Structure

This is a Claude Code plugin. The manifest is at `.claude-plugin/plugin.json`.

Components are auto-discovered from standard directories:

| Directory | Purpose | Format |
|-----------|---------|--------|
| `commands/` | Slash commands (`/hxm:<name>`) | `.md` files with YAML frontmatter |
| `agents/` | Autonomous subagents | `.md` files with YAML frontmatter |
| `skills/<name>/` | Auto-activated knowledge modules | `SKILL.md` per skill |
| `hooks/` | Event-driven automation | `hooks.json` config |

## Conventions

- **Language**: All code, comments, and documentation in English.
- **Naming**: kebab-case for all files and directories.
- **Paths**: Use `${CLAUDE_PLUGIN_ROOT}` for all intra-plugin path references — never hardcode absolute paths.
- **Sorting**: Sort keys and methods by visibility (public > protected > private), then alphabetically.

## Command Frontmatter

```yaml
---
description: What the command does (shown in command list)
allowed-tools: [Tool1, Tool2, Bash(specific-command:*)]
argument-hint: --flag | <required-arg> [optional-arg]
model: haiku | sonnet | opus
---
```

## Git

- All commits via `/hxm:commit` or following its procedure (conventional commits).
- Never commit without explicit user confirmation.
