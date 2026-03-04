---
allowed-tools: Bash(git log:*), Bash(git tag:*), Bash(npm version:*), Bash(cargo set-version:*), Bash(composer config:*), Read, Grep, Bash(git diff:*), Bash(git status:*)
argument-hint: --major | --minor | --patch | --auto
description: Smart version bump tool that analyzes commits and suggests appropriate version increment
model: haiku
---

# /hxm:bump - Smart version bump tool that analyzes commits and suggests appropriate version increment

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
   - Ask user for confirmation: "Proceed with version bump? (yes/no)"
   - If user responds "no" or anything other than "yes": Exit without changes
   - If tag vA.B.C already exists: Exit with error "Tag vA.B.C already exists"

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
     - Update version in appropriate file
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

### Example 1: Auto bump with conventional commits

**Scenario**: Node.js project with several conventional commits since v1.2.3

```bash
$ /hxm:bump --auto
```

**Process**:

1. Pre-flight checks pass (clean working directory)
2. Detected Node.js project (package.json found)
3. Current version: 1.2.3
4. Analyzed commits since v1.2.3:
   - feat: add user profile page
   - feat: implement email notifications
   - fix: resolve login session timeout
   - docs: update API documentation
5. Highest bump level: MINOR (due to feat commits)
6. Calculated new version: 1.3.0
7. Generated message: "1.3.0 - add user profiles and email notifications"
8. Preview shown:
   ```
   Current version: 1.2.3
   New version: 1.3.0
   Bump level: MINOR
   Commits analyzed: 4
   Proposed message: "1.3.0 - add user profiles and email notifications"
   ```
9. User confirms: yes
10. Executed: `npm version minor -m "1.3.0 - add user profiles and email notifications"`
11. Success: Version bumped to 1.3.0, tag v1.3.0 created

### Example 2: Forced major bump

**Scenario**: Rust project requiring breaking changes

```bash
$ /hxm:bump --major
```

**Process**:

1. Pre-flight checks pass
2. Detected Rust project (Cargo.toml found)
3. Current version: 2.4.1
4. Commit analysis skipped (forced level)
5. Calculated new version: 3.0.0
6. Analyzed commits for message generation:
   - refactor: redesign API endpoints
   - feat: add new authentication system
   - chore: update dependencies
7. Generated message: "3.0.0 - redesign API with new authentication"
8. Preview shown and user confirms
9. Executed cargo commands and created tag v3.0.0
10. Success message with reminder to push

### Example 3: Error - dirty working directory

**Scenario**: User has uncommitted changes

```bash
$ /hxm:bump
```

**Output**:

```
Error: Working directory not clean. Commit or stash changes first.
```

**Resolution**: User must commit or stash changes before running bump again

### Example 4: Error - no commits to bump

**Scenario**: Version was just bumped, no new commits

```bash
$ /hxm:bump
```

**Output**:

```
Current version: 1.5.0
Error: No commits since last version. Nothing to bump.
```

**Resolution**: Make commits before attempting to bump version
