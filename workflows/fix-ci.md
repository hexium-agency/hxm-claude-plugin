---
name: fix-ci
description: Diagnose the failing CI checks of a pull request — classify each failure as a branch regression or as flaky, infrastructure or pre-existing noise, fix only the regressions, then offer to commit and push
arguments: [<pr-number-or-url>] [--push]
trigger: Use when the CI of a pull request fails and the user asks why, or asks to fix it. Reads the failing GitHub checks, separates branch regressions from flaky, infrastructure or pre-existing failures, and fixes only the regressions.
requires: gh
---

# Fix Failing CI

Diagnoses the failing CI checks of a pull request, classifying each failure as a real branch regression or as noise the branch did not cause (flaky test, infrastructure, failure already on the base branch). Only regressions are fixed, then verified locally. Never re-runs CI, never posts on the pull request, never pushes without consent.

## Usage

```bash
{{command:fix-ci}} [<pr-number-or-url>] [--push]
```

| Argument | Description |
|----------|-------------|
| `pr-number-or-url` | Optional. Pull request number or URL. Defaults to the current branch's pull request. |
| `--push` | Push the fix commit once created, without asking a second time. |

## Examples

```bash
# Current branch's pull request
{{command:fix-ci}}

# A given pull request, then push the fix
{{command:fix-ci}} 482 --push
```

## Process

### 1. Resolve the Pull Request

Use `pr-number-or-url` if given, else the current branch's pull request:

```bash
gh pr view [<pr-number-or-url>] --json number,url,headRefName,baseRefName,headRefOid
```

- No pull request for the current branch: STOP and tell the user.
- Head branch is not the current branch: STOP and ask whether to check it out, never switch silently.
- Local branch behind or ahead of `headRefOid`: say so, the failing run may not match the local code.

### 2. Read the Failing Checks

```bash
gh pr checks <pr>
gh run view <run-id> --log-failed
```

- List every failing check with its run ID and job name.
- From the failed logs, extract per failure the failing step, the test or command, and the error message.
- Report pending checks as pending, do not wait for them.

### 3. Identify the Branch Diff

From the real fork point with the base branch:

```bash
git fetch origin <base-branch>
git diff $(git merge-base HEAD origin/<base-branch>)..HEAD --stat
git diff $(git merge-base HEAD origin/<base-branch>)..HEAD
```

### 4. Classify Each Failure

Assign exactly one category:

**(a) Branch regression** — caused by code the branch introduced. Confirm by cross-referencing the failing test, lint rule or type error with the step 3 diff: it must be plausibly attributable to a changed file, route, model or behavior.

**(b) Pre-existing on the base branch** — the same check also fails there. Compare with its latest runs:

```bash
gh run list --branch <base-branch> --workflow <workflow-name> --limit 5
gh run view <base-run-id> --log-failed
```

**(c) Flaky or infrastructure** — not caused by code:

- Runner, network or registry errors (timeouts, connection refused, rate limits, failed dependency download)
- Missing or expired secrets, service containers that did not start
- A known flaky test: passed on a previous run of the same commit, or passes locally and fails intermittently on the base branch

If no category fits cleanly, investigate before classifying (read the test, the code under test, compare with the diff). Do not guess.

### 5. Fix the Regressions

- **(a):** fix the branch-introduced code, with the {{command:fix-tests}} philosophy: target the application code, never weaken an assertion to make a test pass. For a Laravel/Pest test failure, follow {{command:fix-tests}} to diagnose locally.
- **(b) and (c):** do NOT touch the code. Explain the cause and remediation (re-run the job, fix the secret, report the flaky test). Never re-run CI yourself: suggest it, the user decides.

No regression: report it and stop, nothing to commit.

### 6. Verify Locally

Run only the tests and checks covering the fixed regressions, using the project's own commands (read `composer.json` / `package.json` scripts and the CI workflow file to match CI).

The local stack (Sail) may be shared between worktrees. Before running anything through Sail, check it is running and belongs to this worktree (`sail ps`, or `docker ps` and the container's project directory). If stopped or held by another worktree, STOP and ask the user: never stop another worktree's stack, never fall back to a non-Sail environment.

If a local run fails, report it and do not commit.

### 7. Offer Commit and Push

- Summarize the changes and propose a conventional commit message per the {{command:commit}} procedure; commit only once the user confirms.
- Push (`git push`) only with `--push` or after explicit confirmation.

**Never force-push. Never push a fix that failed local verification.**

### 8. Summary Table

| Check | Failure | Cause | Action |
|-------|---------|-------|--------|
| `tests (Feature)` | `OrderTest > it stores an order` | Regression — `OrderService::store` signature changed in this branch | Fixed in `app/Services/OrderService.php` |
| `lint` | `npm ci` timed out | Infra — registry timeout | Re-run the job |
| `tests (Browser)` | `CheckoutTest` | Pre-existing — also fails on `develop` | None, reported |

Then the commit and push status.

## Notes

- If the same failure reappears after a fix attempt, diagnose differently, do not repeat the approach.
- When in doubt between regression and pre-existing, compare with the base branch run before touching code.
