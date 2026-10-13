---
name: hxm-fix-ci
description: Use when the CI of a pull request fails and the user asks why, or asks to fix it. Reads the failing GitHub checks, separates branch regressions from flaky, infrastructure or pre-existing failures, and fixes only the regressions.
---

# Fix Failing CI

Diagnoses the failing CI checks of a pull request. Each failure is classified as either a real regression introduced by the branch, or noise the branch did not cause (flaky test, infrastructure, failure already present on the base branch). Only regressions are fixed, then verified locally. The command never re-runs CI, never posts on the pull request, and never pushes without consent.

## Usage

```bash
$hxm-fix-ci [<pr-number-or-url>] [--push]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `pr-number-or-url` | string | Optional. Pull request number or URL. Defaults to the pull request of the current branch. |
| `--push` | flag | Push the fix commit once it is created, without asking a second time. |

## Examples

```bash
# Fix the CI of the current branch's pull request
$hxm-fix-ci

# Fix the CI of a given pull request, then push the fix
$hxm-fix-ci 482 --push
```

## Process

### 1. Resolve the Pull Request

- If `pr-number-or-url` is provided, use it. Otherwise, use the pull request of the current branch:

```bash
gh pr view [<pr-number-or-url>] --json number,url,headRefName,baseRefName,headRefOid
```

- If no pull request exists for the current branch, STOP and tell the user.
- If the pull request's head branch is not the current branch, STOP and ask the user whether to check it out — never switch branches silently.
- If the local branch is behind or ahead of the pull request's head commit (`headRefOid`), say so: the failing run may not match the local code.

### 2. Read the Failing Checks

```bash
gh pr checks <pr>
gh run view <run-id> --log-failed
```

- List every failing check with its run ID and job name.
- Read the failed logs and extract, for each failure, the failing step, the test or command, and the error message.
- Skip checks that are still pending: report them as pending, do not wait for them.

### 3. Identify the Branch Diff

Determine what the branch actually changed, from its real fork point with the pull request's base branch:

```bash
git fetch origin <base-branch>
git diff $(git merge-base HEAD origin/<base-branch>)..HEAD --stat
git diff $(git merge-base HEAD origin/<base-branch>)..HEAD
```

### 4. Classify Each Failure

For every failure, assign exactly one category:

**(a) Branch regression** — the failure is caused by code the branch introduced. Confirm by cross-referencing the failing test, lint rule or type error with the branch diff from step 3: the failure must be plausibly attributable to a changed file, route, model or behavior.

**(b) Pre-existing on the base branch** — the same check also fails on the base branch. Compare with the latest runs of the base branch:

```bash
gh run list --branch <base-branch> --workflow <workflow-name> --limit 5
gh run view <base-run-id> --log-failed
```

**(c) Flaky or infrastructure** — the failure is not caused by code:

- Runner, network or registry errors (timeouts, connection refused, rate limits, failed dependency download)
- Missing or expired secrets, service containers that did not start
- A test known to be flaky: it passed on a previous run of the same commit, or passes locally and fails intermittently on the base branch

If a failure matches no category cleanly, investigate before classifying — read the test, read the code under test, compare with the diff. Do not guess.

### 5. Fix the Regressions

- **Regressions (a):** fix the code introduced by the branch, with the same philosophy as $hxm-fix-tests — target the application code, never weaken an assertion to make a test pass. When a regression is a Laravel/Pest test failure, follow $hxm-fix-tests to diagnose it locally.
- **Pre-existing (b) and flaky or infrastructure (c):** do NOT touch the code. Explain the cause and the remediation (re-run the job, fix the secret, report the flaky test). Never re-run the CI yourself: suggest it and let the user decide.

If no failure is a regression, report it and stop — there is nothing to commit.

### 6. Verify Locally

Run only the tests and checks that cover the fixed regressions, using the project's own commands (read `composer.json` / `package.json` scripts and the CI workflow file to match what CI runs).

The local stack (Sail) may be shared between several worktrees. Before running anything through Sail:

- Check whether the stack is running and whether it belongs to this worktree (`sail ps`, or `docker ps` and the container's project directory).
- If it is stopped, or held by another worktree, STOP and ask the user how to proceed — never stop another worktree's stack, never fall back to a non-Sail environment.

If a local run fails, report it and do not commit.

### 7. Offer Commit and Push

- Summarize the changes and propose a conventional commit message, following the $hxm-commit procedure. Commit only once the user confirms.
- Push only if `--push` was given, or after the user explicitly confirms:

```bash
git push
```

**Never force-push. Never push a fix that failed local verification.**

### 8. Summary Table

End with a recap table:

| Check | Failure | Cause | Action |
|-------|---------|-------|--------|
| `tests (Feature)` | `OrderTest > it stores an order` | Regression — `OrderService::store` signature changed in this branch | Fixed in `app/Services/OrderService.php` |
| `lint` | `npm ci` timed out | Infra — registry timeout | Re-run the job |
| `tests (Browser)` | `CheckoutTest` | Pre-existing — also fails on `develop` | None, reported |

Then the commit and push status.

## Notes

- This command never re-runs CI, never comments on the pull request, and never pushes without `--push` or explicit consent.
- If the same failure reappears after a fix attempt, diagnose differently — do not repeat the same approach.
- When in doubt between a regression and a pre-existing failure, compare with the base branch run before touching the code.

## Prerequisites

- **GitHub CLI (`gh`)**, authenticated against the repository remote.

Configure these as MCP servers in your own Codex configuration. This plugin ships no credentials
and no MCP configuration.

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
