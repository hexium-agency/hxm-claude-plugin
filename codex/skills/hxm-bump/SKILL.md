---
name: hxm-bump
description: Use when the user asks to bump, release or tag a new version of the current project. Analyses conventional commits since the last tag, proposes a major, minor or patch increment, updates the project manifest and creates the matching git tag once the user has confirmed.
---

# Smart Version Bump

## Purpose

Smart version bump tool that analyzes git commit history since the last version to automatically determine whether a major, minor, or patch version increment is appropriate. The tool detects the project type (Claude Code plugin, Node.js, Rust, Python, etc.) and uses the appropriate versioning command with intelligent commit message generation.

## Usage

```bash
/bump [--major] [--minor] [--patch] [--auto]
```

## Arguments

- `--major`: Force a major version bump (X.0.0)
- `--minor`: Force a minor version bump (0.X.0)
- `--patch`: Force a patch version bump (0.0.X)
- `--auto`: Automatically determine version bump based on commit analysis (default behavior)
- No arguments: Same as `--auto`

## Process

1. **Pre-flight Checks**

   - Verify working directory is clean: `git status --porcelain`
   - If uncommitted changes exist: Exit with error "Working directory not clean. Commit or stash changes first."
   - Verify we're in a git repository
   - If no commits exist: Exit with error "No git history found. Create initial commits first."

2. **Project Detection**

   - Check for `.claude-plugin/plugin.json` (Claude Code plugin) — **check this first**: a plugin
     repository may also carry a `package.json` for tooling, and the plugin manifest is what Claude Code
     actually reads
   - Check for `package.json` (Node.js/npm project)
   - Check for `Cargo.toml` (Rust project)
   - Check for `pyproject.toml` or `setup.py` (Python project)
   - Check for `composer.json` (PHP project)
   - If no recognized project files found: Exit with error "No supported project type detected"

3. **Current Version Detection**

   - For Claude Code plugins: Extract version from `.claude-plugin/plugin.json`
   - For npm: Extract version from `package.json`
   - For Rust: Extract version from `Cargo.toml`
   - For Python: Extract version with priority order:
     1. `pyproject.toml` - Check `[project].version` or `[tool.poetry].version`
     2. `setup.py` - Look for `version=` parameter
     3. `__init__.py` - Look for `__version__` variable
   - For others: Use latest git tag matching semver pattern (vX.Y.Z or X.Y.Z)
   - If no version found: Start with 0.0.0

   **Tag convention detection** — run `git tag --list --sort=-v:refname | head -n 1` and reuse the
   existing prefix: if the latest tag looks like `vX.Y.Z`, tag `v[new_version]`; if it looks like
   `X.Y.Z`, tag `[new_version]` with no prefix. Only default to the `v` prefix when the repository has
   no tags yet. Mixing both conventions in one repository breaks tag-based version lookups.
   Below, `[tag]` means the new version rendered with the detected prefix.

4. **Commit Analysis** (only if --auto or no arguments provided)

   - Run `git log --oneline` since last version tag or since project start
   - If no commits since last version: Exit with error "No commits since last version. Nothing to bump."
   - Analyze commit messages for conventional commit patterns:
     - **MAJOR**: Commits containing "BREAKING CHANGE" or "!" in type (e.g., "feat!:" or "fix!:")
     - **MINOR**: Commits starting with "feat:", "feature:"
     - **PATCH**: Commits starting with "fix:", "docs:", "style:", "refactor:", "test:", "chore:", "perf:"
   - Determine highest required bump level from analysis
   - If no conventional commits found: Default to PATCH

5. **Version Calculation**

   - If forced argument provided (--major, --minor, --patch): Use that level
   - If --auto: Use level determined from commit analysis
   - Calculate new version number from current version + bump level
   - Display proposed version with justification

6. **Commit Message Generation**

   - Analyze commits since last version to create descriptive summary
   - Algorithm:
     1. Extract all feat/feature commits for features list
     2. Extract all fix commits for fixes list
     3. Prioritize breaking changes if present
     4. Combine into single concise message (max 80 chars)
   - Focus on user-facing changes (features and fixes)
   - Format: "X.Y.Z - [concise description of main changes]"
   - Examples:
     - "1.2.0 - add user authentication and dashboard improvements"
     - "1.1.1 - fix critical security vulnerability in auth module"
     - "2.0.0 - redesign API with breaking changes to user endpoints"

7. **Preview and Confirmation**

   - Display clear summary:
     ```
     Current version: X.Y.Z
     New version: A.B.C
     Bump level: [MAJOR|MINOR|PATCH]
     Commits analyzed: N
     Proposed message: "A.B.C - [generated message]"
     ```
   - If the tag for A.B.C already exists: Exit with error "Tag [tag] already exists"
   - Ask the user to confirm the bump in plain text (Proceed / Cancel) and wait for the answer
   - If the user does not confirm: Exit without changes

8. **Version Bump Execution**

   - **Claude Code plugins**:
     - Edit the `version` field in `.claude-plugin/plugin.json` using the `Edit` tool
     - If `.claude-plugin/marketplace.json` exists, look up the entry in `plugins[]` whose `name`
       matches the plugin, then:
       - If that entry declares a `version`, update it to `[new_version]` so both manifests agree
       - If it does not, **leave it alone** — do not add one. Claude Code resolves the version from
         `plugin.json` first and silently ignores the marketplace value, so a duplicated version only
         creates drift (see Notes below)
     - If `./scripts/generate-distributions.sh` exists, run it: provider distributions embed the
       version and would otherwise drift from the manifest
     - `git add .claude-plugin/plugin.json` (add `.claude-plugin/marketplace.json` only if it changed,
       plus anything the generation step rewrote)
     - `git commit -m "[new_version] - [generated message]"`
     - `git tag [tag] -m "[new_version] - [generated message]"`
   - **Node.js projects**: `npm version [level] -m "%s - [generated message]"`
   - **Rust projects**:
     - `cargo set-version [new_version]`
     - `git add Cargo.toml Cargo.lock`
     - `git commit -m "[new_version] - [generated message]"`
     - `git tag [tag] -m "[new_version] - [generated message]"`
   - **PHP projects**:
     - `composer config version [new_version]`
     - `git add composer.json`
     - `git commit -m "[new_version] - [generated message]"`
     - `git tag [tag] -m "[new_version] - [generated message]"`
   - **Python projects**:
     - Edit the version string in the appropriate file (`pyproject.toml`, `setup.py`, or `__init__.py`) using the `Edit` tool
     - `git add [version_file]`
     - `git commit -m "[new_version] - [generated message]"`
     - `git tag [tag] -m "[new_version] - [generated message]"`
   - **Other projects**:
     - `git tag [tag] -m "[new_version] - [generated message]"`

9. **Confirmation**
   - If `scripts/check-version-consistency.sh` exists, run it to verify the manifests and the new tag agree
   - Display success message with new version number
   - Show the commit/tag that was created
   - Remind user to push: `git push && git push --tags`
   - If any step fails, display clear error message and exit

## Notes

### Claude Code Plugin Versioning

Claude Code resolves a plugin's version from the first source that is set: the `version` in
`.claude-plugin/plugin.json`, then the `version` in the marketplace entry, then the git commit SHA of
the plugin source. Because `plugin.json` always wins, declaring a version in both manifests lets a
stale entry mask the other one without any warning. Keep `plugin.json` as the single declared version
and let the marketplace entry omit it.

That leaves two things to keep in sync — `plugin.json` and the git tag — which is what
`scripts/check-version-consistency.sh` enforces.

Bumping the version is also what ships the update: users only receive a new version when the string in
`plugin.json` changes, so a release without a bump is invisible to `/plugin update`.

### Commit Message Classification Rules

The tool follows these rules for analyzing conventional commits:

#### Major Version (Breaking Changes)

- Commits with `BREAKING CHANGE:` in body or footer
- Any commit explicitly marked as breaking

#### Minor Version (New Features)

- `feat:` - New features
- `feature:` - Alternative feature syntax
- Significant enhancements that don't break existing functionality

#### Patch Version (Bug Fixes & Maintenance)

- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `style:` - Code formatting changes
- `refactor:` - Code restructuring without behavior changes
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks, build changes
- `perf:` - Performance improvements

### Message Generation Guidelines

- Prioritize user-facing changes in the commit message
- Combine multiple similar changes into concise descriptions
- Use present tense and imperative mood
- Keep messages under 80 characters when possible
- Examples of good messages:
  - "add OAuth integration and user profiles"
  - "fix memory leaks and improve performance"
  - "redesign authentication system with JWT"

## Examples

```bash
# Auto-detect the bump level from conventional commits since the last tag
$hxm-bump --auto

# Force a specific level
$hxm-bump --major
```

**Typical flow** (`$hxm-bump --auto`, Node.js project at v1.2.3): pre-flight checks pass → detect npm project
→ analyze commits since v1.2.3 (two `feat:`, one `fix:`) → highest level MINOR → new version 1.3.0 → preview
and confirm → `npm version minor -m "1.3.0 - add user profiles and email notifications"` → tag v1.3.0 created.

**Claude Code plugin flow** (`$hxm-bump --auto`, plugin at 0.4.2, tags without a `v` prefix): detect
`.claude-plugin/plugin.json` → current version 0.4.2 → latest tag `0.4.2` so the convention is unprefixed
→ analyze commits (one `fix:`) → PATCH → new version 0.4.3 → edit `plugin.json`, leave the marketplace
entry untouched since it declares no version → commit → `git tag 0.4.3` → run
`scripts/check-version-consistency.sh`.

**Common errors:**

- Dirty working directory → `Error: Working directory not clean. Commit or stash changes first.`
- No commits since the last tag → `Error: No commits since last version. Nothing to bump.`

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
