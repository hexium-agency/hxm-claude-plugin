---
name: rebase
description: Rebase the current branch onto its base — resolves trivial conflicts, stops on non-trivial ones, verifies the result (full local CI with --ci) before a safe force-push
arguments: [<base-branch>] [--ci] [--no-push] [instructions]
trigger: Use when the user asks to rebase the current branch, bring it up to date with its base, or resolve rebase conflicts. Auto-resolves trivial conflicts, stops on business-logic ones, verifies the result and force-pushes only with --force-with-lease.
requires: none
---

# Rebase Branch

Rebases the current branch onto the freshly fetched remote base. Trivial conflicts are resolved automatically; non-trivial conflicts stop the process and are presented to the user. A light verification always runs after the rebase; with `--ci`, the full local CI runs instead. Free-form instructions are applied after the rebase and before the push. Force-push only ever happens with `--force-with-lease`, once the rebase is entirely clean.

## Usage

```bash
{{command:rebase}} [<base-branch>] [--ci] [--no-push] [instructions]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `base-branch` | string | Optional. Branch to rebase onto. Defaults to the detected parent branch. Only the first word is taken as a branch, and only if such a branch exists on `origin`. |
| `instructions` | string | Optional. Free-form follow-up applied after the rebase and before the push (e.g. "check whether upstream added new places where this fix applies"). Everything that is not the base branch or a flag. |
| `--ci` | flag | Run the full local CI (tests, lint, type check) instead of the light verification. |
| `--no-push` | flag | Rebase, verify and apply the instructions, then stop and report without pushing. |

## Examples

```bash
# Detected base, light verification, push
{{command:rebase}}

# Explicit base, full local CI before the force-push
{{command:rebase}} develop --ci

# Rebase and verify, but keep the push for later
{{command:rebase}} develop --no-push

# Rebase, then look for new places upstream where the branch's fix applies
{{command:rebase}} develop check whether upstream added new cases this fix should cover
```

## Process

### 1. Determine the Base Branch

- If `base-branch` is provided, use it.
- Otherwise, detect the real parent of the current branch via `git merge-base` against the repo's long-lived branches and `git reflog` — **never hardcode `main` or `develop`**.
- If the parent is ambiguous, STOP and ask the user.

### 2. Prepare the Working Tree

Check `git status`. If there are pending changes (staged, unstaged or untracked), ask the user before touching anything. On their agreement, set the changes aside in a temporary WIP commit:

```bash
git add -A
git commit --no-verify -m "WIP: rebase autosave"
```

**Never use `git stash`** — the stash stack is shared across worktrees. The WIP commit is undone at the end of step 4.

### 3. Fetch and Rebase

Always rebase onto the freshly fetched remote ref — **never onto a local base ref** (`git rebase develop` is forbidden), it may be stale:

```bash
git fetch origin <base-branch>
OLD_BASE=$(git merge-base HEAD origin/<base-branch>)
git rebase origin/<base-branch>
```

Keep `OLD_BASE` (the fork point before the rebase): `OLD_BASE..origin/<base-branch>` is the upstream range the branch was just replayed onto, used by steps 5, 6 and 9. Prefer it over `ORIG_HEAD`, which later commands such as `git reset` overwrite.

### 4. Handle Conflicts

For each conflict, classify it:

- **Trivial — resolve automatically:**
  - Lockfiles (`composer.lock`, `package-lock.json`, `yarn.lock`, ...): re-generate or take the combination that keeps both sides' dependency changes.
  - Import/use statement lists: merge both sides.
  - Pure formatting/whitespace conflicts.
  - Independent additions at the same spot (two new methods, exports, CSS variables, factory columns, ...): keep both, in a sensible order.
- **Non-trivial — STOP:**
  - Business logic conflicts.
  - The same code zone modified on both sides with different intent.

  Present the conflicting hunks (file, both versions, what each side was trying to do) and ask the user how to resolve. Do not guess. Do not abort the rebase unless the user asks.

Note every borderline resolution (same zone with the same intent, a removal on one side against an edit on the other, ...) for the report, even when resolved automatically.

After resolving a conflict: `git add <files>` then `git rebase --continue`. Repeat until the rebase completes.

If a WIP commit was created in step 2, undo it once the rebase is complete: `git reset --soft HEAD~1`. The changes come back staged and stay out of the push.

### 5. Upstream Impact Scan (on request)

Run this step when the `instructions` ask for it (e.g. "check for new cases", "see what upstream changed") or when the branch removes symbols (see step 6):

- List the upstream commits the branch was replayed onto: `git log --oneline OLD_BASE..origin/<base-branch>`.
- Grep their diff (`git diff OLD_BASE origin/<base-branch>`) for the patterns the branch fixes, replaces or removes, and list each new occurrence (file, line, commit) as a candidate for the same change.

Report the candidates; only modify them if the `instructions` explicitly ask for it.

### 6. Verify

Once the rebase is clean, verify the result. If any check fails, STOP and report the failure — do not push.

**Default — light verification (without `--ci`):**

- Type check and lint, according to what the project exposes (check `composer.json` / `package.json` scripts).
- Tests for the files touched by both sides: intersect `git diff --name-only OLD_BASE origin/<base-branch>` with `git diff --name-only origin/<base-branch>...HEAD`, then run the tests covering those files (their own test files, or tests matched by naming convention), following the project's test rules.
- **Removed symbols check:** from the branch diff (`git diff origin/<base-branch>...HEAD`), list the columns, classes, methods, constants and routes the branch deletes or renames. For each one, grep the incoming upstream diff (`git diff OLD_BASE origin/<base-branch>`, added lines) and the rebased tree (`git grep`) for new uses — seeders, factories, tests, migrations included. A textually clean rebase can still reference a symbol the branch removed; treat any hit as a failure.

**With `--ci` — full local CI:** run the full suite according to what the project exposes:

- Tests via sail — following the project's test rules (e.g. `sail artisan test --parallel --compact`, frontend build before Browser suites, suites run sequentially).
- Lint (e.g. `sail composer lint`, `sail npm run lint`).
- Type check (e.g. `sail npm run types`, PHPStan via sail).

The removed symbols check runs in both modes.

### 7. Apply the Instructions

If `instructions` were provided, apply them now — after the rebase and verification, before the push. Stay within what they ask. If they lead to code changes, show them and let the user decide whether to commit before pushing; never push uncommitted work or commit without confirmation.

### 8. Push

Skip this step with `--no-push`. Otherwise, only once the rebase is entirely clean (and verification green), pick the push from the remote state:

```bash
git rev-parse --abbrev-ref --symbolic-full-name @{upstream}
git ls-remote --exit-code --heads origin <current-branch>
```

- **`origin/<current-branch>` exists:** `git push --force-with-lease origin HEAD`.
- **`origin/<current-branch>` does not exist:** `git push -u origin HEAD` — a normal push that creates the remote branch. Say so in the report.
- **The upstream points to a differently named branch** (e.g. `origin/develop`): never push to it. Push to `origin HEAD` with `-u` (with `--force-with-lease` only if `origin/<current-branch>` already exists), which also fixes the tracking.

Note the remote SHA before and after the push for the report.

**Never use `--force`. Never force-push a rebase that is incomplete or has unresolved conflicts.**

If the push is rejected for authentication (e.g. `Permission denied (publickey)`), STOP and give the user the exact command to run themselves.

### 9. Report

- **First line — push status:** `Pushed <old-sha>→<new-sha>` (mention when the remote branch was created) or `Not pushed: <reason>` (`--no-push`, verification failure, empty branch, authentication, ...).
- Base branch used (`origin/<base-branch>`), number of commits replayed, number of upstream commits brought in.
- Conflicts encountered: which were auto-resolved (and how), which required the user, and every borderline resolution.
- Verification results (light or `--ci`), including the removed symbols check.
- Upstream impact scan candidates, and the outcome of the `instructions`, if any.
- **New migrations brought by the base:** detect the project's migrations directory generically (e.g. `database/migrations`, `migrations/`, `db/migrate`, `prisma/migrations`), list the files from `git diff --name-only --diff-filter=A OLD_BASE origin/<base-branch> -- <migrations-dir>`, and recommend running them locally.
- **PR state:** `gh pr view --json number,baseRefName,mergeable` — number, base and mergeability. Flag a PR base that differs from the rebase base. If no PR exists, suggest {{command:create-pr}}.

## Notes

- `--force-with-lease` is the only accepted force-push flag: it fails if the remote moved since the last fetch, protecting teammates' work.
- If the rebase produces an empty branch (all commits already upstream), report it and skip the push.
- When in doubt about a conflict's triviality, treat it as non-trivial.
