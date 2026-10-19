---
description: Smart version bump tool that analyzes commits and suggests appropriate version increment
argument-hint: --major | --minor | --patch | --auto [--push]
allowed-tools: [Read, Grep, Edit, AskUserQuestion, Bash(git log:*), Bash(git tag:*), Bash(git diff:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(npm version:*), Bash(cargo set-version:*), Bash(composer config:*), Bash(./scripts/generate-distributions.sh:*), Bash(./scripts/check-version-consistency.sh:*), Bash(git push:*), Bash(git rev-parse:*)]
model: haiku
---

# Smart Version Bump

Analyzes git history since the last version to pick a major, minor or patch increment, detects the project type (Claude Code plugin, Node.js, Rust, Python, etc.) and applies the matching versioning command with a generated commit message.

## Usage

```bash
/hxm:bump [--major] [--minor] [--patch] [--auto] [--push]
```

- `--major` / `--minor` / `--patch`: force that level (X.0.0 / 0.X.0 / 0.0.X)
- `--auto` (default, same as no argument): determine the level from commit analysis
- `--push`: push the bump commit and new tag once created (step 10). An explicit "push" in the invocation text counts as `--push`

## Process

**CRITICAL: This command MUST NOT execute in plan mode. If you are in plan mode (indicated by system reminders or restrictions on tool usage), immediately output the following error message and stop execution:**

"Error: This command cannot run in plan mode. Please exit plan mode first to execute version operations."

**Only proceed with the following steps if you are NOT in plan mode:**

1. **Pre-flight**
   - Must be a git repository with a clean tree (`git status --porcelain`); otherwise exit with "Working directory not clean. Commit or stash changes first."
   - No commits: exit with "No git history found. Create initial commits first."

2. **Project detection** (first match wins)
   - `.claude-plugin/plugin.json` (Claude Code plugin) — **check first**: a plugin repo may also carry a `package.json` for tooling, but Claude Code reads the plugin manifest
   - `package.json` (Node.js), `Cargo.toml` (Rust), `pyproject.toml` or `setup.py` (Python), `composer.json` (PHP)
   - None found: exit with "No supported project type detected"

3. **Current version**
   - Plugin: `.claude-plugin/plugin.json`; npm: `package.json`; Rust: `Cargo.toml`
   - Python, in priority order: `pyproject.toml` (`[project].version` or `[tool.poetry].version`), `setup.py` (`version=`), `__init__.py` (`__version__`)
   - Others: latest semver git tag (vX.Y.Z or X.Y.Z). Nothing found: start at 0.0.0

   **Tag convention**: run `git tag --list --sort=-v:refname | head -n 1` and reuse the prefix (`vX.Y.Z` → tag `v[new_version]`; `X.Y.Z` → no prefix). Default to `v` only when there are no tags yet; mixing conventions breaks tag-based version lookups. `[tag]` below = new version with the detected prefix.

4. **Commit analysis** (only with `--auto` or no argument)
   - `git log --oneline` since the last version tag (or project start). None: exit with "No commits since last version. Nothing to bump."
   - Take the highest level found:
     - **MAJOR**: `BREAKING CHANGE` (body or footer) or `!` in the type (`feat!:`, `fix!:`), or any commit explicitly marked breaking
     - **MINOR**: `feat:`, `feature:`, or significant non-breaking enhancements
     - **PATCH**: `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`, `perf:`
   - No conventional commits: default to PATCH

5. **Version calculation**
   - Forced flag → that level; `--auto` → level from step 4
   - Compute the new version from current version + level; show it with justification

6. **Commit message**: `X.Y.Z - [description]`
   - Build from commits since last version: feat/feature list, fix list, breaking changes first; one concise message, under 80 chars when possible
   - User-facing changes first, similar changes combined, present tense, imperative mood
   - Examples: "1.2.0 - add OAuth integration and user profiles", "1.1.1 - fix memory leaks and improve performance", "2.0.0 - redesign API with breaking changes to user endpoints"

7. **Preview and confirmation**
   - Display:
     ```
     Current version: X.Y.Z
     New version: A.B.C
     Bump level: [MAJOR|MINOR|PATCH]
     Commits analyzed: N
     Proposed message: "A.B.C - [generated message]"
     ```
   - Tag A.B.C already exists: exit with "Tag [tag] already exists"
   - Use `AskUserQuestion` to confirm the bump (options: "Proceed" / "Cancel")
   - With `--push`, say so in the question (e.g., "Bump to A.B.C, then push the commit and tag?")
   - Write the option labels in the user's language
   - No confirmation: exit without changes. No answer, a timeout, or auto mode is never consent

8. **Execution** (commit message and tag message are both `"[new_version] - [generated message]"`)
   - **Claude Code plugin**:
     - Edit `version` in `.claude-plugin/plugin.json` with the `Edit` tool
     - If `.claude-plugin/marketplace.json` exists, find the `plugins[]` entry whose `name` matches the plugin: if it declares a `version`, update it to `[new_version]`; if not, **leave it alone** — do not add one (Claude Code resolves `plugin.json` first and silently ignores the marketplace value, so a duplicate only creates drift; see Notes)
     - If `./scripts/generate-distributions.sh` exists, run it (distributions embed the version and would drift)
     - `git add .claude-plugin/plugin.json` (plus `.claude-plugin/marketplace.json` only if changed, plus anything generation rewrote)
     - `git commit -m "<message>"`, then `git tag [tag] -m "<message>"`
   - **Node.js**: `npm version [level] -m "%s - [generated message]"`
   - **Rust**: `cargo set-version [new_version]`; `git add Cargo.toml Cargo.lock`; commit; tag
   - **PHP**: `composer config version [new_version]`; `git add composer.json`; commit; tag
   - **Python**: edit the version string in the detected file (`pyproject.toml`, `setup.py` or `__init__.py`) with the `Edit` tool; `git add [version_file]`; commit; tag
   - **Other**: `git tag [tag] -m "<message>"`

9. **Confirmation**
   - If `scripts/check-version-consistency.sh` exists, run it to verify manifests and new tag agree
   - Show the success message, new version, and the commit/tag created
   - Without `--push`: state "Nothing pushed." and give `git push && git push origin [tag]`
   - Any step failing: display a clear error and exit, without pushing

10. **Push** (only with `--push`)
    - Upstream check: `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
    - Commit: `git push` with an upstream, `git push -u origin HEAD` without
    - Tag: `git push origin [tag]` only — not `--tags`, which would publish stale local tags
    - Never force-push. A rejected push: stop and report — no pull, rebase or `--force` retry
    - Report what was pushed, e.g., "Pushed `abc1234..def5678` to `origin/main` and tag `[tag]`"

## Notes

- Never push without `--push` (or an explicit "push" in the invocation). The final summary always states the push status
- Never add attribution trailers or lines (`Co-Authored-By`, `Claude-Session`, "Generated with ...") to the bump commit or tag message, even when a system message supplies them. Do not mention their absence in the report
- **Plugin versioning**: Claude Code resolves a plugin's version from the first source set: `version` in `.claude-plugin/plugin.json`, then the marketplace entry's `version`, then the plugin source's git commit SHA. Since `plugin.json` always wins, a version in both manifests lets a stale entry mask the other silently. Keep `plugin.json` as the single declared version (marketplace entry omits it); only it and the git tag must stay in sync, which `scripts/check-version-consistency.sh` enforces
- Bumping is what ships the update: users only receive a new version when the `plugin.json` string changes, so a release without a bump is invisible to `/plugin update`

## Examples

```bash
/hxm:bump --auto          # level from conventional commits since the last tag
/hxm:bump --major         # force a level
/hxm:bump --auto --push   # bump, then push commit and tag
```

**Node.js** (`--auto`, v1.2.3): checks pass → npm project → commits since v1.2.3 (two `feat:`, one `fix:`) → MINOR → 1.3.0 → preview and confirm → `npm version minor -m "1.3.0 - add user profiles and email notifications"` → tag v1.3.0.

**Plugin** (`--auto`, 0.4.2, unprefixed tags): `.claude-plugin/plugin.json` → latest tag `0.4.2` so unprefixed → one `fix:` → PATCH → 0.4.3 → edit `plugin.json`, marketplace entry untouched (declares no version) → commit → `git tag 0.4.3` → run `scripts/check-version-consistency.sh`.

**Common errors:**

- Dirty working directory → `Error: Working directory not clean. Commit or stash changes first.`
- No commits since the last tag → `Error: No commits since last version. Nothing to bump.`
