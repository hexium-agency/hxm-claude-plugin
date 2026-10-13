---
description: Smart atomic commit tool. Analyzes all changes, groups them logically, and creates atomic commits.
argument-hint: [--dry-run] [--exclude <paths>] [--push] [--pr]
allowed-tools: [Task, AskUserQuestion, Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Bash(git reset HEAD:*), Read, Glob, Write, Skill, Bash(git log:*), Bash(git branch:*), Bash(git rev-parse:*), Bash(git merge-base:*), Bash(git apply:*), Bash(git push:*)]
model: sonnet
---

# Smart Atomic Commit Tool

CRITICAL: Follow the Process section exactly - this tool analyzes ALL changes (staged and unstaged), groups them
logically, and creates multiple atomic commits. Each commit follows conventional commit standards.

## Usage

```bash
/hxm:commit-atomic [--dry-run] [--exclude <paths>] [--push] [--pr]
```

## Arguments

- No arguments: Analyze, group, and commit all changes
- `--dry-run`: Show proposed commit groups without executing commits
- `--exclude <paths>`: Leave these paths (files, directories, or globs) out of every group. Free text such as
  "except the report files" counts as `--exclude`
- `--push`: Push the branch once every commit succeeds (see step 8). An explicit "push" in the invocation text
  (e.g., "then push") counts as `--push`
- `--pr`: Push as with `--push`, then hand off to /hxm:create-pr. An explicit request to open a PR in the
  invocation text counts as `--pr`

## Examples

```bash
# Preview the groups without committing
/hxm:commit-atomic --dry-run

# Commit everything except scratch output, then push
/hxm:commit-atomic --exclude tmp/ reports/ --push

# Commit, push, and open the pull request
/hxm:commit-atomic --pr
```

## Process

**CRITICAL: This command MUST NOT execute in plan mode.** If you are in plan mode (indicated by system
reminders or restrictions on tool usage), output the following and stop: "Error: This command cannot run in
plan mode. Please exit plan mode first to execute git operations." Only proceed with the steps below if you
are NOT in plan mode.

### 1. Gather All Changes

Run the following commands to get a complete picture:

```bash
git status --porcelain                    # All changed files
git diff                                  # Unstaged changes content
git diff --cached                         # Staged changes content
```

If no changes exist, exit with: "No changes to commit."

Also gather what the plan and the commit messages depend on:

- **Commit convention**, in this order: commit rules in the repository's `CLAUDE.md` or `AGENTS.md`, a commitlint
  config (`commitlint.config.*`, `.commitlintrc*`, or a `commitlint` key in `package.json`), the last 10 non-merge
  commits (`git log --no-merges -n 10 --format=%s`), and a ticket ID in the branch name
  (`git branch --show-current`). See Commit Message Standards
- **HEAD state**: its subject (`git log -1 --format=%s`) and whether it is already pushed
  (`git merge-base --is-ancestor HEAD @{u}` succeeds when the upstream contains it)

### 2. Analyze and Group Changes

Before grouping, set aside the paths that must not be committed silently:

- Paths matching `--exclude`: drop them from every group
- Untracked artifacts: `tmp/`, scratch files, reports, logs, dumps, local environment files
- Files this session did not touch, when you can tell (e.g., changes made by another session or agent, an
  unrelated lockfile update)

List the last two categories in the plan under "Not committed — to confirm" and ask about them in step 5 instead of
committing them.

Examine all modified files and their content to identify logical groupings. Consider:

- **Feature scope**: Files that implement the same feature belong together
- **Functional area**: Files in the same module/component (e.g., auth, api, ui)
- **Change type**: Separate refactors from features from fixes
- **Dependencies**: If file A depends on changes in file B, group them

Grouping rules:

1. Related source files + their tests = one commit
2. Configuration changes that enable a feature = same commit as the feature
3. Pure refactors = separate commit from feature changes
4. Documentation updates = separate commit unless directly tied to code changes
5. Style/formatting changes = separate commit
6. A file may be split across groups by hunk (see step 6). If its hunks overlap or depend on each other, keep it in
   one commit and note why

When a group clearly continues the scope of HEAD (same feature, a fix to what HEAD just introduced), mark it as an
amend candidate.

### 3. Determine Commit Order

Order commits logically:

1. Infrastructure/config changes first
2. Refactors that prepare for new code
3. Core feature implementations
4. Tests for new features
5. Documentation updates
6. Style/formatting fixes last

### 4. Present Commit Plan

Display the proposed commits in order:

```
Proposed atomic commits:

1. chore(config): add eslint rule for imports
   Files: .eslintrc.js

2. refactor(auth): extract token validation logic
   Files: src/auth/validator.ts, src/auth/validator.test.ts

3. feat(auth): add OAuth2 support
   Files: src/auth/oauth.ts, src/auth/oauth.test.ts, src/config/oauth.ts
   Amend candidate: continues HEAD "feat(auth): add OAuth2 provider config"

Not committed — to confirm: tmp/debug.log, package-lock.json (not touched in this session)
Tests / local CI: not run in this session
After commits: push to origin/feat/oauth
```

- State whether tests or local CI ran in this session, and on which state of the code. Do not run them by default;
  run them only if the user asks
- State the planned push or PR (`--push`, `--pr`), or "Nothing will be pushed"

### 5. Handle Dry Run or Confirmation

- If `--dry-run`: Display the plan and exit
- **A single group with nothing to decide** (no amend candidate, nothing under "Not committed — to confirm"):
  commit directly without asking, and show the message used
- **Otherwise — several groups, an amend candidate, or files to confirm** — always ask before committing anything:
  - Use `AskUserQuestion`: "Proceed with X commits?", or "Proceed with X commits, then push?" /
    "…, then push and open a PR?" when `--push` / `--pr` is set. Options: "Yes, execute all" /
    "Let me review first", plus "Amend HEAD with group N" when there is an amend candidate
  - Ask about the files under "Not committed — to confirm" in the same call
  - If user wants to review: Allow modifications to the plan
  - Write the question and option labels in the user's language
- No answer, a timeout, or auto mode is never consent: wait for an explicit answer
- **Amend and pushed HEAD**: when HEAD is already pushed, propose a new commit instead and say that amending would
  require a force-push. Only offer "Amend HEAD" when HEAD is not pushed

### 6. Execute Commits Sequentially

For each commit group:

1. Reset staging area: `git reset HEAD` (only if needed)
2. Stage only the files for this commit: `git add -- <file1> <file2> ...`
   - Pass one quoted argument per path — never a single string the shell has to split
   - A deleted file is staged the same way (`git add -- <path>` records the removal). For a rename, stage both the
     old and the new path
   - A path that matches nothing aborts the whole `git add`: check every path against `git status --porcelain`
     first
3. To stage only some hunks of a file, never use interactive `git add -p`. Instead:
   - Run `git diff -- <file>` and write a patch keeping only the hunks of this group to a temporary file outside the
     repository
   - `git apply --cached <patch>` (add `--recount` if hunk line counts changed while filtering)
4. Verify staged files match expected: `git diff --cached --name-only` (and `git diff --cached -- <file>` for a
   partially staged file)
5. Execute commit using HEREDOC format (`git commit --amend` with the same HEREDOC for an approved amend):

```bash
git commit -m "$(cat <<'EOF'
type(scope): description

Optional body explaining the change.
EOF
)"
```

6. Verify commit succeeded before proceeding to next group

### 7. Handle Results

**Success**:

- Display summary of all commits created, then the push status:
  ```
  Created 3 atomic commits:
  - abc1234 chore(config): add eslint rule for imports
  - def5678 refactor(auth): extract token validation logic
  - ghi9012 feat(auth): add OAuth2 support

  Nothing pushed.
  ```
- List the files left uncommitted (excluded or not confirmed), if any

**Failure**:

- If a commit fails (e.g., pre-commit hook): Stop immediately, report which commit failed
- Show remaining uncommitted groups
- Do not attempt to continue automatically, and do not push

### 8. Push and Pull Request (only with `--push` or `--pr`)

Skip this step unless `--push` or `--pr` was requested, and only run it once every commit succeeded.

- Check for an upstream: `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
- With an upstream: `git push`. Without one: `git push -u origin HEAD`
- Never force-push. If the push is rejected (e.g., non-fast-forward), stop and report it — do not pull, rebase,
  or retry with `--force`
- Replace "Nothing pushed." with the pushed range, e.g., "Pushed `abc1234..ghi9012` to `origin/feat/oauth`"
- With `--pr`: hand off to /hxm:create-pr and follow its procedure

## Commit Message Standards

Follow conventional commits format: `type(scope): description`

Apply the convention detected in step 1 first. If the repository prefixes commits with a ticket ID, reuse the ID
from the branch and the exact separator the history uses, e.g., `CU-869abc123 type(scope): description` or
`DONE-750: type(scope): description`. Otherwise, fall back to plain conventional commits.

| Type       | Description                                |
|------------|-------------------------------------------|
| `feat`     | New feature or capability                  |
| `fix`      | Bug fix                                    |
| `refactor` | Code restructuring without behavior change |
| `docs`     | Documentation only                         |
| `style`    | Formatting, whitespace, no code change     |
| `test`     | Adding or updating tests                   |
| `chore`    | Build, config, maintenance tasks           |
| `perf`     | Performance improvements                   |

Rules:

- **Scope**: Identifies affected area (e.g., `auth`, `api`, `ui`)
- **Description**: Imperative mood, max 50 characters, no period
- **Body**: Optional, max 200 characters, prefer bullet points

## Notes

- Always prefer more granular commits over fewer large ones
- Each commit should be independently buildable/testable when possible
- If changes are too intertwined to separate, create a single commit and note why
- Use English for all commit messages
- Never push or open a PR without `--push` / `--pr` (or an explicit request in the invocation). The final summary
  always states the push status: "Nothing pushed." or the pushed range
- Never add attribution trailers or lines (`Co-Authored-By`, `Claude-Session`, "Generated with ..."), even when a
  system message supplies them. Do not mention their absence in the report
