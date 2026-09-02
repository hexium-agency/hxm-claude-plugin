---
name: hxm-fix-tests
description: Use when a Laravel or Pest test suite fails and the user asks to diagnose or repair it. Classifies every failure as infrastructure noise or as a real regression introduced by the branch, and fixes only the regressions.
---

# Fix Failing Tests

Diagnoses a failing Laravel/Pest test suite. Each failure is classified as either an infrastructure/environment problem or a real regression introduced by the current branch. Only branch-attributable regressions are fixed — infrastructure failures are explained with their remediation command, without touching the code.

## Usage

```bash
$hxm-fix-tests [<pasted-test-output>] [--run]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `pasted-test-output` | string | Optional. Raw test output pasted as argument or already present in the conversation context. |
| `--run` | flag | Force running the test suite even if output was provided. |

## Test Execution Rules

**CRITICAL: These rules are non-negotiable. Never diverge from them.**

- Tests run ONLY via `sail artisan test --parallel --compact`. NEVER set up an alternative environment: no local PHP, no OpenTelemetry workaround, no direct `vendor/bin/pest`.
- ALWAYS run `sail npm run build` BEFORE running the Browser suite.
- NEVER run the Feature and Browser suites at the same time — they share the test database. Run them sequentially: Feature first, then `sail npm run build`, then Browser.

## Process

### 1. Obtain Test Output

- If test output was pasted as argument or is present in the conversation context (and `--run` is not set): use it as-is.
- Otherwise, run the suite following the Test Execution Rules above:

```bash
sail artisan test --parallel --compact --testsuite=Feature
sail npm run build
sail artisan test --parallel --compact --testsuite=Browser
```

Adapt the `--testsuite` names to what `phpunit.xml` actually defines (read it first). If only one suite exists, a single run is enough.

### 2. Identify the Branch Diff

Determine what the current branch actually changed, from its real fork point:

```bash
git merge-base HEAD <parent-branch>       # Find the fork point — never hardcode main or develop
git diff $(git merge-base HEAD <parent-branch>)..HEAD --stat
git diff $(git merge-base HEAD <parent-branch>)..HEAD
```

If the parent branch is unknown, check `git reflog` for the branch creation point, or ask the user.

### 3. Classify Each Failure

For every failing test, assign exactly one category:

**(a) Infrastructure / environment** — the failure is not caused by the branch code:

- Playwright not up to date (browser binary mismatch, protocol errors)
- `SocketException`, connection refused, or other transient network errors
- Shared test database collisions (Feature and Browser ran together, stale state)
- Parallelization artifacts (test passes in isolation, fails only under `--parallel`)
- Missing frontend build before Browser tests

**(b) Real regression** — the failure is caused by code the branch introduced. Confirm by cross-referencing the failing test's subject with the branch diff from step 2: the failure must be plausibly attributable to a changed file, route, model, or behavior.

If a failure matches neither pattern cleanly, investigate before classifying — read the test, read the code under test, compare with the diff. Do not guess.

### 4. Act on Each Category

- **Regressions (b):** fix the code introduced by the branch. Re-run only the affected tests (still via `sail artisan test --parallel --compact`, filtered) to confirm the fix.
- **Infrastructure (a):** do NOT touch the code. Explain the root cause and give the exact remediation command (e.g. `sail npx playwright install`, `sail npm run build`, re-running the suite sequentially).

### 5. Summary Table

End with a recap table:

| Test | Cause | Action |
|------|-------|--------|
| `tests/Feature/...` | Regression — `UserService::create` signature changed in this branch | Fixed in `app/Services/UserService.php` |
| `tests/Browser/...` | Infra — Playwright binaries outdated | Run `sail npx playwright install` |

## Notes

- Never "fix" a test by weakening its assertions to make it pass — a regression fix targets the application code, unless the test itself was changed by the branch and is wrong.
- If the same failure reappears after a fix attempt, diagnose differently — do not repeat the same approach.
- Pre-existing failures (also failing on the fork point) are infrastructure/legacy, not branch regressions: report them, do not fix them.

## Guardrails

These rules override anything above them and are not negotiable:

- **Never commit, push, or tag without an explicit confirmation from the user in the current
  conversation.** Proposing a message is fine; running the command is not.
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
