---
name: hxm-commit-atomic
description: Use when the user asks to split pending work into several atomic commits, or to commit a large working tree mixing unrelated changes. Groups changes by logical unit and creates one conventional commit per group after explicit confirmation.
---

# Smart Atomic Commit Tool

CRITICAL: Follow the Process section exactly - this tool analyzes ALL changes (staged and unstaged), groups them
logically, and creates multiple atomic conventional commits.

## Usage

```bash
$hxm-commit-atomic [--dry-run] [--exclude <paths>] [--push] [--pr]
```

- No arguments: analyze, group, and commit all changes
- `--dry-run`: show proposed commit groups without committing
- `--exclude <paths>`: leave these paths (files, directories, or globs) out of every group. Free text such as
  "except the report files" counts as `--exclude`
- `--push`: push the branch once every commit succeeds (step 8). An explicit "push" in the invocation text counts as
  `--push`
- `--pr`: push as with `--push`, then hand off to $hxm-create-pr. An explicit request to open a PR in the
  invocation text counts as `--pr`

```bash
$hxm-commit-atomic --exclude tmp/ reports/ --push
```

## Process

### 1. Gather All Changes

Run `git status --porcelain` (changed files), `git diff` (unstaged content) and `git diff --cached` (staged
content). No changes: exit with "No changes to commit."

Also gather:

- **Commit convention**, in this order: commit rules in the repository's `CLAUDE.md` or `AGENTS.md`, a commitlint
  config (`commitlint.config.*`, `.commitlintrc*`, or a `commitlint` key in `package.json`), the last 10 non-merge
  commits (`git log --no-merges -n 10 --format=%s`), and a ticket ID in the branch name
  (`git branch --show-current`). See Commit Message Standards
- **HEAD state**: its subject (`git log -1 --format=%s`) and whether it is already pushed
  (`git merge-base --is-ancestor HEAD @{u}` succeeds when the upstream contains it)

### 2. Analyze and Group Changes

First set aside paths that must not be committed silently:

- Paths matching `--exclude`: drop from every group
- Untracked artifacts: `tmp/`, scratch files, reports, logs, dumps, local environment files
- Files this session did not touch, when you can tell (e.g., changes by another session or agent, an unrelated
  lockfile update)

List the last two categories in the plan under "Not committed — to confirm" and ask about them in step 5 instead of
committing them.

Group by: feature scope (same feature together), functional area (same module/component, e.g., auth, api, ui),
change type (separate refactors, features, fixes), and dependencies (if file A depends on file B's changes, group
them).

Grouping rules:

1. Related source files + their tests = one commit
2. Configuration enabling a feature = same commit as the feature
3. Pure refactors = separate commit from feature changes
4. Documentation = separate commit unless directly tied to code changes
5. Style/formatting = separate commit
6. A file may be split across groups by hunk (step 6). If its hunks overlap or depend on each other, keep it in one
   commit and note why

When a group clearly continues the scope of HEAD (same feature, a fix to what HEAD just introduced), mark it as an
amend candidate.

### 3. Determine Commit Order

1. Infrastructure/config
2. Refactors preparing new code
3. Core feature implementations
4. Tests for new features
5. Documentation
6. Style/formatting last

### 4. Present Commit Plan

```
Proposed atomic commits:

1. chore(config): add eslint rule for imports
   Files: .eslintrc.js

2. feat(auth): add OAuth2 support
   Files: src/auth/oauth.ts, src/auth/oauth.test.ts, src/config/oauth.ts
   Amend candidate: continues HEAD "feat(auth): add OAuth2 provider config"

Not committed — to confirm: tmp/debug.log, package-lock.json (not touched in this session)
Tests / local CI: not run in this session
After commits: push to origin/feat/oauth
```

- State whether tests or local CI ran in this session, and on which state of the code. Do not run them by default;
  only if the user asks
- State the planned push or PR (`--push`, `--pr`), or "Nothing will be pushed"

### 5. Handle Dry Run or Confirmation

- `--dry-run`: display the plan and exit
- **Single group with nothing to decide** (no amend candidate, nothing under "Not committed — to confirm"): commit
  directly without asking, and show the message used
- **Otherwise** (several groups, an amend candidate, or files to confirm): always ask before committing anything:
  - Ask in plain text, and wait for the answer before committing anything: "Proceed with X commits?", or
    "Proceed with X commits, then push?" / "…, then push and open a PR?" when `--push` / `--pr` is set. Options:
    "Yes, execute all" / "Let me review first", plus "Amend HEAD with group N" when there is an amend candidate
  - Ask about the files under "Not committed — to confirm" in the same message
  - "Let me review first": allow modifications to the plan
  - Write the question and option labels in the user's language
- No answer, a timeout, or auto mode is never consent: wait for an explicit answer
- **Pushed HEAD**: propose a new commit instead of an amend and say that amending would require a force-push. Only
  offer "Amend HEAD" when HEAD is not pushed

### 6. Execute Commits Sequentially

For each group:

1. Reset staging if needed: `git reset HEAD`
2. Stage only this group's files: `git add -- <file1> <file2> ...`
   - One quoted argument per path, never a single string the shell has to split
   - A deleted file is staged the same way (`git add -- <path>` records the removal). For a rename, stage both the
     old and the new path
   - A path matching nothing aborts the whole `git add`: check every path against `git status --porcelain` first
3. To stage only some hunks of a file, never use interactive `git add -p`. Instead:
   - Run `git diff -- <file>` and write a patch keeping only this group's hunks to a temporary file outside the
     repository
   - `git apply --cached <patch>` (add `--recount` if hunk line counts changed while filtering)
4. Verify staged files match: `git diff --cached --name-only` (and `git diff --cached -- <file>` for a partially
   staged file)
5. Commit with a HEREDOC (`git commit --amend` with the same HEREDOC for an approved amend):

```bash
git commit -m "$(cat <<'EOF'
type(scope): description

Optional body explaining the change.
EOF
)"
```

6. Verify the commit succeeded before the next group

### 7. Handle Results

- **Success**: display all commits created, then the push status; list the files left uncommitted (excluded or not
  confirmed), if any:
  ```
  Created 2 atomic commits:
  - abc1234 chore(config): add eslint rule for imports
  - def5678 feat(auth): add OAuth2 support

  Nothing pushed.
  ```
- **Failure** (e.g., pre-commit hook): stop immediately, report which commit failed, show the remaining
  uncommitted groups. Do not continue automatically and do not push

### 8. Push and Pull Request (only with `--push` or `--pr`)

Run only once every commit succeeded.

- Check for an upstream: `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
- With an upstream: `git push`. Without one: `git push -u origin HEAD`
- Never force-push. If the push is rejected (e.g., non-fast-forward), stop and report it — do not pull, rebase, or
  retry with `--force`
- Replace "Nothing pushed." with the pushed range, e.g., "Pushed `abc1234..def5678` to `origin/feat/oauth`"
- With `--pr`: hand off to $hxm-create-pr and follow its procedure

## Commit Message Standards

Format: `type(scope): description`. Apply the convention detected in step 1 first. If the repository prefixes
commits with a ticket ID, reuse the ID from the branch and the exact separator the history uses, e.g.,
`CU-869abc123 type(scope): description` or `DONE-750: type(scope): description`. Otherwise use plain conventional
commits.

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

- **Scope**: affected area (e.g., `auth`, `api`, `ui`)
- **Description**: imperative mood, max 50 characters, no period
- **Body**: optional, max 200 characters, prefer bullet points

## Notes

- Prefer more granular commits over fewer large ones; each commit independently buildable/testable when possible
- If changes are too intertwined to separate, create a single commit and note why
- Use English for all commit messages
- Never push or open a PR without `--push` / `--pr` (or an explicit request in the invocation). The final summary
  always states the push status: "Nothing pushed." or the pushed range
- Never add attribution trailers or lines (`Co-Authored-By`, `Claude-Session`, "Generated with ..."), even when a
  system message supplies them. Do not mention their absence in the report

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
