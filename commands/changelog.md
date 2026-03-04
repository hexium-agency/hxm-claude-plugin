---
description: Generate a changelog from conventional commits since the last version tag
allowed-tools: Bash(git log:*), Bash(git tag:*), Read, Write, Edit
argument-hint: [--from <tag>] [--to <ref>] [--output <file>]
model: haiku
---

# /hxm:changelog - Changelog Generator

Generates a changelog by analyzing conventional commits since the last version tag. Complements `/hxm:bump` by producing human-readable release notes.

## Usage

```bash
/hxm:changelog [--from <tag>] [--to <ref>] [--output <file>]
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
/hxm:changelog

# Generate changelog between two versions
/hxm:changelog --from v1.2.0 --to v1.3.0

# Write changelog to file
/hxm:changelog --output CHANGELOG.md

# Generate changelog since a specific tag to HEAD
/hxm:changelog --from v2.0.0
```

## Process

### 1. Determine Range

1. If `--from` is provided, use it as the start point
2. Otherwise, find the latest version tag:
   ```bash
   git tag --sort=-v:refname | head -1
   ```
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
- Pairs well with `/hxm:bump`: run `/hxm:changelog --output CHANGELOG.md` before bumping the version.
