---
name: rebase
description: Rebase the current branch onto its base — resolves trivial conflicts, stops on non-trivial ones, optionally runs local CI before a safe force-push
arguments: [<base-branch>] [--ci]
trigger: Use when the user asks to rebase the current branch, bring it up to date with its base, or resolve rebase conflicts. Auto-resolves trivial conflicts, stops on business-logic ones and force-pushes only with --force-with-lease.
requires: none
---

# Rebase Branch

Rebases the current branch onto its base branch. Trivial conflicts are resolved automatically; non-trivial conflicts stop the process and are presented to the user. With `--ci`, the full local CI runs before pushing. Force-push only ever happens with `--force-with-lease`, once the rebase is entirely clean.

## Usage

```bash
{{command:rebase}} [<base-branch>] [--ci]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `base-branch` | string | Optional. Branch to rebase onto. Defaults to the detected parent branch. |
| `--ci` | flag | Run the full local CI (tests, lint, type check) before pushing. |

## Process

### 1. Determine the Base Branch

- If `base-branch` is provided, use it.
- Otherwise, detect the real parent of the current branch via `git merge-base` against the repo's long-lived branches and `git reflog` — **never hardcode `main` or `develop`**.
- If the parent is ambiguous, STOP and ask the user.

### 2. Fetch and Rebase

```bash
git fetch
git rebase origin/<base-branch>
```

Verify the working tree is clean before starting; if not, STOP and ask the user how to handle pending changes.

### 3. Handle Conflicts

For each conflict, classify it:

- **Trivial — resolve automatically:**
  - Lockfiles (`composer.lock`, `package-lock.json`, `yarn.lock`, ...): re-generate or take the combination that keeps both sides' dependency changes.
  - Import/use statement lists: merge both sides.
  - Pure formatting/whitespace conflicts.
- **Non-trivial — STOP:**
  - Business logic conflicts.
  - The same code zone modified on both sides with different intent.

  Present the conflicting hunks (file, both versions, what each side was trying to do) and ask the user how to resolve. Do not guess. Do not abort the rebase unless the user asks.

After resolving a conflict: `git add <files>` then `git rebase --continue`. Repeat until the rebase completes.

### 4. Run Local CI (only with `--ci`)

Once the rebase is clean, run the full local CI according to what the project exposes (check `composer.json` / `package.json` scripts):

- Tests via sail — following the project's test rules (e.g. `sail artisan test --parallel --compact`, frontend build before Browser suites, suites run sequentially).
- Lint (e.g. `sail composer lint`, `sail npm run lint`).
- Type check (e.g. `sail npm run types`, PHPStan via sail).

If any step fails, STOP and report the failure — do not push.

### 5. Push

Only once the rebase is entirely clean (and CI green when `--ci` was requested):

```bash
git push --force-with-lease
```

**Never use `--force`. Never force-push a rebase that is incomplete or has unresolved conflicts.**

### 6. Report

- Base branch used, number of commits replayed.
- Conflicts encountered: which were auto-resolved (and how), which required the user.
- CI results if `--ci` was used.
- Push status.

## Notes

- `--force-with-lease` is the only accepted force-push flag: it fails if the remote moved since the last fetch, protecting teammates' work.
- If the rebase produces an empty branch (all commits already upstream), report it and skip the push.
- When in doubt about a conflict's triviality, treat it as non-trivial.
