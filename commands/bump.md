---
description: Smart version bump tool that analyzes commits and suggests appropriate version increment
argument-hint: --major | --minor | --patch | --auto
allowed-tools: [Read, Grep, Edit, AskUserQuestion, Bash(git log:*), Bash(git tag:*), Bash(git diff:*), Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(npm version:*), Bash(cargo set-version:*), Bash(composer config:*)]
model: haiku
---

# Smart Version Bump

## Purpose

Smart version bump tool that analyzes git commit history since the last version to automatically determine whether a major, minor, or patch version increment is appropriate. The tool detects the project type (Node.js, Rust, Python, etc.) and uses the appropriate versioning command with intelligent commit message generation.

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

**CRITICAL: This command MUST NOT execute in plan mode. If you are in plan mode (indicated by system reminders or restrictions on tool usage), immediately output the following error message and stop execution:**

"Error: This command cannot run in plan mode. Please exit plan mode first to execute version operations."

**Only proceed with the following steps if you are NOT in plan mode:**

1. **Pre-flight Checks**

   - Verify working directory is clean: `git status --porcelain`
   - If uncommitted changes exist: Exit with error "Working directory not clean. Commit or stash changes first."
   - Verify we're in a git repository
   - If no commits exist: Exit with error "No git history found. Create initial commits first."

2. **Project Detection**

   - Check for `package.json` (Node.js/npm project)
   - Check for `Cargo.toml` (Rust project)
   - Check for `pyproject.toml` or `setup.py` (Python project)
   - Check for `composer.json` (PHP project)
   - If no recognized project files found: Exit with error "No supported project type detected"

3. **Current Version Detection**

   - For npm: Extract version from `package.json`
   - For Rust: Extract version from `Cargo.toml`
   - For Python: Extract version with priority order:
     1. `pyproject.toml` - Check `[project].version` or `[tool.poetry].version`
     2. `setup.py` - Look for `version=` parameter
     3. `__init__.py` - Look for `__version__` variable
   - For others: Use latest git tag matching semver pattern (vX.Y.Z or X.Y.Z)
   - If no version found: Start with 0.0.0

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
   - If tag vA.B.C already exists: Exit with error "Tag vA.B.C already exists"
   - Use `AskUserQuestion` to confirm the bump (options: "Proceed" / "Cancel")
   - If the user does not confirm: Exit without changes

8. **Version Bump Execution**

   - **Node.js projects**: `npm version [level] -m "%s - [generated message]"`
   - **Rust projects**:
     - `cargo set-version [new_version]`
     - `git add Cargo.toml Cargo.lock`
     - `git commit -m "[new_version] - [generated message]"`
     - `git tag v[new_version] -m "[new_version] - [generated message]"`
   - **PHP projects**:
     - `composer config version [new_version]`
     - `git add composer.json`
     - `git commit -m "[new_version] - [generated message]"`
     - `git tag v[new_version] -m "[new_version] - [generated message]"`
   - **Python projects**:
     - Edit the version string in the appropriate file (`pyproject.toml`, `setup.py`, or `__init__.py`) using the `Edit` tool
     - `git add [version_file]`
     - `git commit -m "[new_version] - [generated message]"`
     - `git tag v[new_version] -m "[new_version] - [generated message]"`
   - **Other projects**:
     - `git tag v[new_version] -m "[new_version] - [generated message]"`

9. **Confirmation**
   - Display success message with new version number
   - Show the commit/tag that was created
   - Remind user to push: `git push && git push --tags`
   - If any step fails, display clear error message and exit

## Notes

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
/hxm:bump --auto

# Force a specific level
/hxm:bump --major
```

**Typical flow** (`/hxm:bump --auto`, Node.js project at v1.2.3): pre-flight checks pass → detect npm project
→ analyze commits since v1.2.3 (two `feat:`, one `fix:`) → highest level MINOR → new version 1.3.0 → preview
and confirm → `npm version minor -m "1.3.0 - add user profiles and email notifications"` → tag v1.3.0 created.

**Common errors:**

- Dirty working directory → `Error: Working directory not clean. Commit or stash changes first.`
- No commits since the last tag → `Error: No commits since last version. Nothing to bump.`
