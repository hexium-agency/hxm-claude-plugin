# Hexium Claude Code Plugin

A Claude Code plugin built for the Hexium dev team. It provides shared tools and workflows to standardize development practices across the team.

## Installation

Add the marketplace (once), then install the plugin:

```shell
/plugin marketplace add hexium-agency/hxm-claude-plugin
/plugin install hxm@hexium-tools
```

To update manually, run `/plugin update` in Claude Code.

## Development

Clone the repo and load the plugin locally:

```bash
git clone git@github.com:hexium-agency/hxm-claude-plugin.git
claude --plugin-dir ./hxm-claude-plugin
```

## Plugin Structure

```
.claude-plugin/
├── plugin.json        # Plugin manifest (single source of truth for the version)
└── marketplace.json   # hexium-tools marketplace catalog
commands/              # Slash commands (/hxm:<command>)
agents/                # Autonomous subagents
scripts/               # Repository maintenance scripts
```

## Releasing

Run `/hxm:bump` to bump `.claude-plugin/plugin.json` and create the matching git tag, then
`git push && git push --tags`. Users only receive an update when that version string changes.

The version is declared in `plugin.json` only — the marketplace entry deliberately omits it, since
Claude Code reads `plugin.json` first and would silently ignore a marketplace value. CI enforces that
`plugin.json` and the latest git tag agree; run the same check locally with:

```bash
./scripts/check-version-consistency.sh
```

## Prerequisites

- [Claude Code](https://code.claude.com) CLI
- A ClickUp MCP server (for ticket-related commands: `/hxm:plan-ticket`, `/hxm:estimate-ticket`, `/hxm:spec-ticket`, `/hxm:wrap-up`, `/hxm:handle-feedback`)

## Contributing

See [CLAUDE.md](CLAUDE.md) for development guidelines.

## License

[MIT](LICENSE)
