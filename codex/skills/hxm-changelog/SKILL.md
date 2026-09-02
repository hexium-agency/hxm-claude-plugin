---
name: hxm-changelog
description: Use when the user asks for a changelog, release notes, or a summary of what shipped since a given tag. Groups conventional commits between two git refs by type and writes the result to stdout or to a file.
---

# Changelog Generator

Generates a changelog by analyzing conventional commits since the last version tag. Complements `$hxm-bump` by producing human-readable release notes.

## Usage

```bash
$hxm-changelog [--from <tag>] [--to <ref>] [--output <file>]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `--from` | string | Starting tag (default: latest version tag) |
| `--to` | string | End reference (default: HEAD) |
| `--output` | string | Output file path (default: print to console) |

## Examples

```bash
# Generate changelog since last tag
$hxm-changelog

# Generate changelog between two versions
$hxm-changelog --from v1.2.0 --to v1.3.0

# Write changelog to file
$hxm-changelog --output CHANGELOG.md

# Generate changelog since a specific tag to HEAD
$hxm-changelog --from v2.0.0
```

## Process

### 1. Determine Range

1. If `--from` is provided, use it as the start point
2. Otherwise, find the latest version tag by running `git tag --sort=-v:refname` and taking the first line of
   the output.
3. If no tags exist, use the first commit as the start point
4. Use `--to` as the end point, or HEAD if not specified

### 2. Collect Commits

```bash
git log <from>..<to> --oneline --no-merges
```

If no commits are found, exit with: "No commits found in the specified range."

### 3. Categorize Commits

Group commits by conventional commit type:

| Section | Commit Types |
|---------|-------------|
| Breaking Changes | Commits with `BREAKING CHANGE` or `!` suffix |
| Features | `feat:`, `feature:` |
| Bug Fixes | `fix:` |
| Performance | `perf:` |
| Refactoring | `refactor:` |
| Documentation | `docs:` |
| Tests | `test:` |
| Chores | `chore:`, `style:` |

Non-conventional commits go under "Other Changes".

### 4. Generate Changelog

Format:

```markdown
## [Unreleased] (or version if --to is a tag)

### Breaking Changes
- description (scope)

### Features
- description (scope)

### Bug Fixes
- description (scope)
```

Rules:
- Only include sections that have commits
- Strip the type prefix from the description
- Include scope in parentheses if present
- Order sections: Breaking Changes > Features > Bug Fixes > Performance > Refactoring > Documentation > Tests > Chores > Other
- Use sentence case for descriptions

### 5. Output

- If `--output` is specified:
  - If the file exists, prepend the new changelog entry above existing content
  - If the file does not exist, create it with a `# Changelog` header
- If no `--output`: Print the changelog to the console

## Notes

- This command is read-only unless `--output` is specified.
- Merge commits are excluded to avoid noise.
- Pairs well with `$hxm-bump`: run `$hxm-changelog --output CHANGELOG.md` before bumping the version.

## Guardrails

These rules override anything above them and are not negotiable:

- **Never commit, push, or tag without an explicit confirmation from the user in the current
  conversation.** Proposing a message is fine; running the command is not.
- **Never force-push.** The only accepted form is `git push --force-with-lease`, and only inside the
  rebase workflow, once the rebase is entirely clean.
- **Stop when the parent branch is ambiguous.** Detect it via `git merge-base` and `git reflog` —
  never hardcode `main` or `develop`, and ask the user rather than guessing.
- **Never post to ClickUp or GitHub on the user's behalf.** Tickets, comments and reviews are
  read-only: draft the reply as text and let the user post it.
- **Never expand the scope.** Implement exactly what was asked; suggest related work instead of doing
  it, and do not refactor or rename adjacent code.
- **Never invent an external tool.** If a required MCP server or CLI is unavailable, say so and
  continue with a degraded but honest result.
