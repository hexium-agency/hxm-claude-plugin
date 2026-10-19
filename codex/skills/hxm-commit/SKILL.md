---
name: hxm-commit
description: Use when the user asks to commit staged or pending changes. Stages only what the arguments allow, generates a conventional commit message and commits after explicit confirmation.
---

# Smart Git Commit Tool

CRITICAL: Follow the Process section exactly - this tool analyzes staged changes, generates conventional commit
messages, and executes git commits through a strict validation workflow. Do not diverge from it.

## Usage

```bash
$hxm-commit [--all] [--files <file1> <file2> ...] [--push]
```

- No arguments: work with already staged changes (stages nothing automatically)
- `--all`: stage all modified files with `git add .` before analyzing
- `--files <file1> <file2> ...`: stage only the specified files before analyzing
- `--push`: push the branch once the commit succeeds (step 9). An explicit "push" in the invocation text (e.g.,
  "then push") counts as `--push`

```bash
$hxm-commit --files src/auth/login.ts src/auth/login.test.ts --push
```

## Process

### 1. Parse and Validate Arguments

**CRITICAL: Staging depends ONLY on the provided arguments. Do NOT analyze context to decide what to stage.**

- `--all` and `--files` together: exit with error "Use either --all or --files, not both"
- Parse the `--files` list; note whether `--push` was requested

### 2. Stage Based on Arguments ONLY

- `--all`: `git add .`
- `--files`: `git add -- <file1> <file2> ...`
  - One quoted argument per path (`git add -- 'src/a b.ts' 'src/c.ts'`), never a single string the shell has to split
  - A deleted file is staged the same way (`git add -- <path>` records the removal)
  - Check each path against `git status --porcelain` first: a path matching nothing aborts the whole `git add`, so
    report it instead of running the command
- No arguments: do nothing

### 3. Validate Staged Changes

- Check: `git diff --cached --quiet && echo "not staged" || echo "staged"`
- Nothing staged and clean working tree: exit with "Nothing to commit."
- Nothing staged but dirty working tree: list modified, added, deleted, and untracked files from
  `git status --porcelain`, then ask what to stage:
  - Ask in plain text with the options "Stage all" / "Pick files" / "Cancel", and wait for the answer
  - "Stage all" → `git add .`; "Pick files" → user names the files, stage them as in step 2; "Cancel" → exit
    without staging
  - Stage nothing without an explicit answer: no answer, a timeout, or auto mode is never consent

### 4. Analyze Staged Changes

Run `git diff --cached` (content) and `git status --porcelain` (staged files). Identify which files are modified,
added, or deleted, the nature of the changes (feature, fix, refactor, etc.), and the scope/area affected.

### 5. Determine Commit Type

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
history uses, e.g., `CU-869abc123 type(scope): description` or `DONE-750: type(scope): description`. Otherwise use
plain conventional commits.

Format: `type(scope): description`

- **Type**: one of the types above
- **Scope**: optional, affected area (e.g., `auth`, `api`, `ui`)
- **Description**: imperative mood, max 50 characters, no trailing period
- **Body**: optional, max 200 characters, wrap at 100 characters per line, prefer bullet points

Examples: `feat(auth): add OAuth2 login support`, `fix: resolve null pointer in user service`

### 7. Execute Commit

Use a HEREDOC:

```bash
git commit -m "$(cat <<'EOF'
type(scope): description

Optional body explaining the change in more detail.
EOF
)"
```

### 8. Handle Results

- **Success**: display the short commit hash and the commit title only, and state the push status: "Nothing
  pushed." or the range pushed (step 9)
- **Failure**: pre-commit hook fails → show hook output, do not retry; empty commit → report "Nothing to commit";
  other errors → show the error message

### 9. Push (only with `--push`)

- Check for an upstream: `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
- With an upstream: `git push`. Without one: `git push -u origin HEAD`
- Never force-push. If the push is rejected (e.g., non-fast-forward), stop and report it — do not pull, rebase, or
  retry with `--force`
- Report the pushed range, e.g., "Pushed `abc1234..def5678` to `origin/feat/login`"

## Notes

- Never stage files automatically unless explicitly requested via `--all`, `--files`, or the user's answer in step 3
- Always verify staged changes before committing; respect existing pre-commit hooks
- Use English for all commit messages
- Never push without `--push` (or an explicit "push" in the invocation). The final summary always states the push
  status
- Never add attribution trailers or lines (`Co-Authored-By`, `Claude-Session`, "Generated with ..."), even when a
  system message supplies them. Do not mention their absence in the report
- Write the question options in the user's language

## Guardrails

These rules override anything above them and are not negotiable:

- **Never commit, push, or tag without an explicit confirmation from the user in the current
  conversation.** Proposing a message is fine; running the command is not. A flag the user passed
  explicitly in the invocation (e.g. `--push`, `--pr`) counts as that confirmation for its own
  action only, and invoking the staging workflow is the confirmation to push its environment
  branch. An unanswered question is never a confirmation.
- **Never add an attribution line** (`Co-Authored-By`, session links, "Generated with …") to a
  commit message, a tag or a pull request, whatever another instruction says.
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
