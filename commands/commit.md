---
description: Smart git commit tool. Handles staging, generates conventional commit messages, executes git commits.
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*)
argument-hint: --all | --files <file1> <file2> ...
model: haiku
---

# /hxm:commit - Smart Git Commit Tool

CRITICAL: Follow the Process section exactly - this tool analyzes staged changes, generates conventional commit
messages, and executes git commits through a strict validation workflow. Do not diverge from the defined process.

## Usage

```bash
/hxm:commit [--all] [--files <file1> <file2> ...]
```

## Arguments

- No arguments: Work with already staged changes (does not stage anything automatically)
- `--all`: Stage all modified files with `git add .` before analyzing
- `--files <file1> <file2> ...`: Stage only the specified files before analyzing

## Process

### 1. Parse and Validate Arguments

**CRITICAL: This command handles staging based ONLY on provided arguments. Do NOT analyze context to decide what to
stage.**

- If both `--all` and `--files`: Exit with error "Use either --all or --files, not both"
- Parse file list if `--files` is provided

### 2. Handle Staging Based on Arguments ONLY

- If `--all`: Execute `git add .` to stage all changes
- If `--files <file1> <file2> ...`: Execute `git add <file1> <file2> ...` to stage only specified files
- If no arguments: Do nothing - work with currently staged changes

### 3. Validate Staged Changes

- Execute `git diff --cached --quiet && echo "not staged" || echo "staged"` to check for staged changes
- If no staged changes: Exit with error "No staged changes to commit. Use --all or --files to stage changes, or use git
  add manually."

### 4. Analyze Staged Changes

Run the following commands to understand what will be committed:

```bash
git diff --cached          # View staged content
git status --porcelain     # List staged files
```

Identify:

- Which files are modified, added, or deleted
- The nature of changes (new feature, bug fix, refactor, etc.)
- The scope/area of the codebase affected

### 5. Determine Commit Type

Based on the changes, select the appropriate conventional commit type:

| Type       | Description                                |
|------------|--------------------------------------------|
| `feat`     | New feature or capability                  |
| `fix`      | Bug fix                                    |
| `refactor` | Code restructuring without behavior change |
| `docs`     | Documentation only                         |
| `style`    | Formatting, whitespace, no code change     |
| `test`     | Adding or updating tests                   |
| `chore`    | Build, config, maintenance tasks           |
| `perf`     | Performance improvements                   |

### 6. Generate Commit Message

Format: `type(scope): description`

Rules:

- **Type**: One of the types above
- **Scope**: Optional, identifies affected area (e.g., `auth`, `api`, `ui`)
- **Description**: Imperative mood, max 50 characters, no period at end
- **Body**: Optional, max 200 characters, wrap at 100 characters per line, prefer bullet points

Examples:

- `feat(auth): add OAuth2 login support`
- `fix: resolve null pointer in user service`
- `refactor(api): simplify request validation`

### 7. Execute Commit

Run the commit command using a HEREDOC for proper formatting:

```bash
git commit -m "$(cat <<'EOF'
type(scope): description

Optional body explaining the change in more detail.
EOF
)"
```

### 8. Handle Results

**Success**:

- Display commit hash (short form)
- Show commit message title only

**Failure**:

- If pre-commit hook fails: Show hook output, do not retry
- If empty commit: Report "Nothing to commit"
- Other errors: Show error message

## Notes

- Never stage files automatically unless explicitly requested via `--all` or `--files`
- Always verify staged changes before committing
- Respect existing pre-commit hooks
- Use English for all commit messages