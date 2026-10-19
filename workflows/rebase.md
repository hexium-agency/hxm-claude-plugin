---
name: rebase
description: Rebase the current branch onto its base — resolves trivial conflicts, stops on non-trivial ones, verifies the result (full local CI with --ci) before a safe force-push
arguments: [<base-branch>] [--ci] [--no-push] [instructions]
trigger: Use when the user asks to rebase the current branch, bring it up to date with its base, or resolve rebase conflicts. Auto-resolves trivial conflicts, stops on business-logic ones, verifies the result and force-pushes only with --force-with-lease.
requires: none
---

# Rebase Branch

Rebases the current branch onto the freshly fetched remote base. Trivial conflicts are auto-resolved; non-trivial ones stop the process and go to the user. A light verification always runs afterwards (full local CI with `--ci`). Free-form instructions apply after the rebase, before the push. Force-push only ever happens with `--force-with-lease`, once the rebase is entirely clean.

## Usage

```bash
{{command:rebase}} [<base-branch>] [--ci] [--no-push] [instructions]
```

| Argument | Type | Description |
|----------|------|-------------|
| `base-branch` | string | Optional. Branch to rebase onto. Default: detected parent. Only the first word is taken as a branch, and only if it exists on `origin`. |
| `instructions` | string | Optional. Everything that is not the base branch or a flag; follow-up applied after the rebase, before the push (e.g. "check whether upstream added new places where this fix applies"). |
| `--ci` | flag | Run the full local CI (tests, lint, type check) instead of the light verification. |
| `--no-push` | flag | Rebase, verify, apply the instructions, then stop and report without pushing. |

```bash
{{command:rebase}}                       # detected base, light verification, push
{{command:rebase}} develop --ci          # full local CI before the force-push
{{command:rebase}} develop --no-push     # keep the push for later
{{command:rebase}} develop check whether upstream added new cases this fix should cover
```

## Process

### 1. Determine the Base Branch

Use `base-branch` if provided. Otherwise detect the real parent via `git merge-base` against the long-lived branches and `git reflog`, **never hardcode `main` or `develop`**. If ambiguous, STOP and ask the user.

### 2. Prepare the Working Tree

Check `git status`. If there are pending changes (staged, unstaged or untracked), ask the user before touching anything. On agreement, set them aside in a temporary WIP commit:

```bash
git add -A
git commit --no-verify -m "WIP: rebase autosave"
```

**Never use `git stash`** (the stash stack is shared across worktrees). The WIP commit is undone at the end of step 4.

### 3. Fetch and Rebase

Always rebase onto the freshly fetched remote ref, **never a local base ref** (`git rebase develop` is forbidden, it may be stale):

```bash
git fetch origin <base-branch>
OLD_BASE=$(git merge-base HEAD origin/<base-branch>)
git rebase origin/<base-branch>
```

Keep `OLD_BASE` (pre-rebase fork point): `OLD_BASE..origin/<base-branch>` is the upstream range the branch was replayed onto, used by steps 5, 6 and 9. Prefer it over `ORIG_HEAD`, which later commands such as `git reset` overwrite.

### 4. Handle Conflicts

Classify each conflict:

- **Trivial, resolve automatically:**
  - Lockfiles (`composer.lock`, `package-lock.json`, `yarn.lock`, ...): re-generate or take the combination keeping both sides' dependency changes.
  - Import/use statement lists: merge both sides.
  - Pure formatting/whitespace.
  - Independent additions at the same spot (two new methods, exports, CSS variables, factory columns, ...): keep both, sensible order.
- **Non-trivial, STOP:** business logic conflicts; same code zone modified on both sides with different intent. Present the hunks (file, both versions, what each side was trying to do) and ask how to resolve. Do not guess. Do not abort the rebase unless the user asks.

When in doubt, treat as non-trivial. Note every borderline resolution (same zone with the same intent, removal on one side against an edit on the other, ...) for the report, even if auto-resolved.

After resolving: `git add <files>` then `git rebase --continue`, until the rebase completes. Then, if a WIP commit was created in step 2, undo it with `git reset --soft HEAD~1` (changes come back staged and stay out of the push).

### 5. Upstream Impact Scan (on request)

Run when `instructions` ask for it (e.g. "check for new cases", "see what upstream changed") or when the branch removes symbols (step 6):

- List upstream commits: `git log --oneline OLD_BASE..origin/<base-branch>`.
- Grep their diff (`git diff OLD_BASE origin/<base-branch>`) for the patterns the branch fixes, replaces or removes; list each new occurrence (file, line, commit) as a candidate for the same change.

Report the candidates; modify them only if `instructions` explicitly ask.

### 6. Verify

Once the rebase is clean, verify. If any check fails, STOP and report it; do not push.

**Light verification (default, without `--ci`):**

- Type check and lint, per what the project exposes (`composer.json` / `package.json` scripts).
- Tests for files touched by both sides: intersect `git diff --name-only OLD_BASE origin/<base-branch>` with `git diff --name-only origin/<base-branch>...HEAD`, run the tests covering those files (their own test files, or matched by naming convention), following the project's test rules.

**Full local CI (`--ci`)**, per what the project exposes:

- Tests via sail, following the project's test rules (e.g. `sail artisan test --parallel --compact`, frontend build before Browser suites, suites run sequentially).
- Lint (e.g. `sail composer lint`, `sail npm run lint`).
- Type check (e.g. `sail npm run types`, PHPStan via sail).

**Removed symbols check (both modes):** from the branch diff (`git diff origin/<base-branch>...HEAD`), list the columns, classes, methods, constants and routes the branch deletes or renames. For each, grep the incoming upstream diff (`git diff OLD_BASE origin/<base-branch>`, added lines) and the rebased tree (`git grep`) for new uses, seeders, factories, tests and migrations included. A textually clean rebase can still reference a removed symbol; any hit is a failure.

### 7. Apply the Instructions

If provided, apply `instructions` now (after rebase and verification, before the push), staying within what they ask. If they lead to code changes, show them and let the user decide whether to commit before pushing; never push uncommitted work or commit without confirmation.

### 8. Push

Skip with `--no-push`. Otherwise, only once the rebase is entirely clean (and verification green), choose the push from the remote state:

```bash
git rev-parse --abbrev-ref --symbolic-full-name @{upstream}
git ls-remote --exit-code --heads origin <current-branch>
```

- **`origin/<current-branch>` exists:** `git push --force-with-lease origin HEAD`.
- **It does not exist:** `git push -u origin HEAD` (normal push creating the remote branch); say so in the report.
- **Upstream points to a differently named branch** (e.g. `origin/develop`): never push to it. Push to `origin HEAD` with `-u` (with `--force-with-lease` only if `origin/<current-branch>` already exists), which also fixes the tracking.

Note the remote SHA before and after for the report.

**Never use `--force`. Never force-push an incomplete rebase or one with unresolved conflicts.** `--force-with-lease` is the only accepted force flag: it fails if the remote moved since the last fetch, protecting teammates' work.

If the push is rejected for authentication (e.g. `Permission denied (publickey)`), STOP and give the user the exact command to run themselves.

### 9. Report

- **First line, push status:** `Pushed <old-sha>→<new-sha>` (mention when the remote branch was created) or `Not pushed: <reason>` (`--no-push`, verification failure, empty branch, authentication, ...).
- Base used (`origin/<base-branch>`), commits replayed, upstream commits brought in.
- Conflicts: auto-resolved (and how), those that required the user, every borderline resolution.
- Verification results (light or `--ci`), including the removed symbols check.
- Upstream impact scan candidates, and the outcome of the `instructions`, if any.
- **New migrations brought by the base:** detect the migrations directory generically (e.g. `database/migrations`, `migrations/`, `db/migrate`, `prisma/migrations`), list `git diff --name-only --diff-filter=A OLD_BASE origin/<base-branch> -- <migrations-dir>`, recommend running them locally.
- **PR state:** `gh pr view --json number,baseRefName,mergeable`: number, base, mergeability. Flag a PR base that differs from the rebase base. If no PR exists, suggest {{command:create-pr}}.

## Notes

If the rebase produces an empty branch (all commits already upstream), report it and skip the push.
