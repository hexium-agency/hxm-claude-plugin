---
description: Smart git commit tool. Handles staging, generates conventional commit messages, executes git commits.
argument-hint: --all | --files <file1> <file2> ... [--push]
allowed-tools: [Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Read, Glob, AskUserQuestion, Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git push:*)]
model: haiku
---

# Smart Git Commit Tool

CRITICAL: Follow the Process section exactly - this tool analyzes staged changes, generates conventional commit
messages, and executes git commits through a strict validation workflow. Do not diverge from the defined process.

## Usage

```bash
/hxm:commit [--all] [--files <file1> <file2> ...] [--push]
```

## Arguments

- No arguments: Work with already staged changes (does not stage anything automatically)
- `--all`: Stage all modified files with `git add .` before analyzing
- `--files <file1> <file2> ...`: Stage only the specified files before analyzing
- `--push`: Push the branch once the commit succeeds (see step 9). An explicit "push" in the invocation text
  (e.g., "then push") counts as `--push`

## Examples

```bash
# Commit what is already staged
/hxm:commit

# Stage two files, commit them, then push
/hxm:commit --files src/auth/login.ts src/auth/login.test.ts --push
```

## Process

**CRITICAL: This command MUST NOT execute in plan mode.** If you are in plan mode (indicated by system
reminders or restrictions on tool usage), output the following and stop: "Error: This command cannot run in
plan mode. Please exit plan mode first to execute git operations." Only proceed with the steps below if you
are NOT in plan mode.

### 1. Parse and Validate Arguments

**CRITICAL: This command handles staging based ONLY on provided arguments. Do NOT analyze context to decide what to
stage.**

- If both `--all` and `--files`: Exit with error "Use either --all or --files, not both"
- Parse file list if `--files` is provided
- Note whether `--push` was requested

### 2. Handle Staging Based on Arguments ONLY

- If `--all`: Execute `git add .` to stage all changes
- If `--files <file1> <file2> ...`: Execute `git add -- <file1> <file2> ...` to stage only specified files
  - Pass one quoted argument per path (`git add -- 'src/a b.ts' 'src/c.ts'`) — never a single string the shell
    has to split
  - A deleted file is staged the same way (`git add -- <path>` records the removal)
  - Check each path against `git status --porcelain` first: a path that matches nothing aborts the whole
    `git add`, so report it instead of running the command
- If no arguments: Do nothing - work with currently staged changes

### 3. Validate Staged Changes

- Execute `git diff --cached --quiet && echo "not staged" || echo "staged"` to check for staged changes
- If no staged changes and the working tree is clean: Exit with "Nothing to commit."
- If no staged changes but the working tree is dirty: List the modified, added, deleted, and untracked files from
  `git status --porcelain`, then ask the user what to stage:
  - Use `AskUserQuestion` with the options "Stage all" / "Pick files" / "Cancel"
  - "Stage all" → `git add .`; "Pick files" → let the user name the files, then stage them as in step 2;
    "Cancel" → exit without staging anything
  - Stage nothing without an explicit answer: no answer, a timeout, or auto mode is never consent

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

**Detect the repository convention first**, in this order:

1. Commit rules in the repository's `CLAUDE.md` or `AGENTS.md`
2. A commitlint config (`commitlint.config.*`, `.commitlintrc*`, or a `commitlint` key in `package.json`)
3. The last 10 non-merge commits: `git log --no-merges -n 10 --format=%s`
4. A ticket ID in the branch name (`git branch --show-current`, e.g., `CU-869abc123`, `DONE-750`)

If the repository prefixes commits with a ticket ID, reuse the ID from the branch and the exact separator the
history uses, e.g., `CU-869abc123 type(scope): description` or `DONE-750: type(scope): description`. Otherwise,
fall back to plain conventional commits.

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
- State the push status: "Nothing pushed." or the range pushed (see step 9)

**Failure**:

- If pre-commit hook fails: Show hook output, do not retry
- If empty commit: Report "Nothing to commit"
- Other errors: Show error message

### 9. Push (only with `--push`)

Skip this step unless `--push` was requested.

- Check for an upstream: `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
- With an upstream: `git push`. Without one: `git push -u origin HEAD`
- Never force-push. If the push is rejected (e.g., non-fast-forward), stop and report it — do not pull, rebase,
  or retry with `--force`
- Report the pushed range, e.g., "Pushed `abc1234..def5678` to `origin/feat/login`"

## Notes

- Never stage files automatically unless explicitly requested via `--all`, `--files`, or the user's answer in
  step 3
- Always verify staged changes before committing
- Respect existing pre-commit hooks
- Use English for all commit messages
- Never push without `--push` (or an explicit "push" in the invocation). The final summary always states the push
  status
- Never add attribution trailers or lines (`Co-Authored-By`, `Claude-Session`, "Generated with ..."), even when a
  system message supplies them. Do not mention their absence in the report
- Write the question options in the user's language
