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
└── plugin.json        # Plugin manifest
commands/              # Slash commands (/hxm:<command>)
agents/                # Autonomous subagents
```

## Prerequisites

- [Claude Code](https://code.claude.com) CLI
- A ClickUp MCP server (for ticket-related commands: `/hxm:plan-ticket`, `/hxm:estimate-ticket`, `/hxm:spec-ticket`, `/hxm:wrap-up`)

## Contributing

See [CLAUDE.md](CLAUDE.md) for development guidelines.

## License

[MIT](LICENSE)
