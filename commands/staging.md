---
description: Merge the current branch into an environment branch (staging by default) and push it to deploy — resolves trivial conflicts, stops on non-trivial ones, never rebases or force-pushes
argument-hint: [<env-branch>] [--no-push]
allowed-tools: [Read, Edit, Glob, AskUserQuestion, Bash(git fetch:*), Bash(git status:*), Bash(git branch:*), Bash(git switch:*), Bash(git merge:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Bash(git push origin HEAD:*)]
model: sonnet
---

# Merge into an Environment Branch

Merges the current feature branch into an environment branch (`staging` by default) and pushes it, so the environment deploys the feature. The merge happens on a detached checkout of the remote environment branch, so no local copy of that branch is created or rewritten. Trivial conflicts are resolved automatically; non-trivial conflicts stop the process. The environment branch is never rebased and never force-pushed. Running the command is the consent to push the environment branch.

## Usage

```bash
/hxm:staging [<env-branch>] [--no-push]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `env-branch` | string | Optional. Environment branch to merge into. Defaults to `staging`, or to the environment branch the project's conventions name. |
| `--no-push` | flag | Stop after the merge and show the summary, without pushing the environment branch. |

## Examples

```bash
# Merge the current branch into staging and push staging
/hxm:staging

# Merge into a differently named environment branch, without pushing
/hxm:staging preprod --no-push
```

## Process

### 1. Determine the Environment Branch

- If `env-branch` is provided, use it.
- Otherwise, look for the project's convention: the deployment workflows (`.github/workflows/`), `CLAUDE.md`, `README` and the remote branches (`git branch -r`). Use `staging` when it exists on the remote and nothing says otherwise.
- If no environment branch can be determined, or several candidates exist, STOP and ask the user.

**Guard — refuse and STOP** when the environment branch is:

- a production or integration branch: `main`, `master`, `develop`, `production`, `prod`, `release` or `release/*`, `live`;
- the base branch of the current branch's pull request;
- the current branch itself.

Never merge into such a branch with this command, even if the user insists — tell them to do it by hand.

### 2. Check the Starting Point

```bash
git status
git branch --show-current
```

- The working tree must be clean. If not, STOP and ask the user how to handle pending changes.
- HEAD must be on a named branch (the feature branch). Remember its name to come back to it in step 6.
- If the feature branch has commits that are not pushed to its own remote branch, say so: they will reach the environment without being on the feature branch's remote.

### 3. Fetch and Check Out the Environment Branch

```bash
git fetch origin
git switch --detach origin/<env-branch>
```

If `origin/<env-branch>` does not exist, STOP and tell the user — never create an environment branch.

### 4. Merge the Feature Branch

```bash
git merge --no-ff <feature-branch>
```

Merge only — **never rebase the feature branch onto the environment branch, never rebase the environment branch**.

For each conflict, classify it with the same rules as /hxm:rebase:

- **Trivial — resolve automatically:**
  - Lockfiles (`composer.lock`, `package-lock.json`, `yarn.lock`, ...): re-generate or take the combination that keeps both sides' dependency changes.
  - Import/use statement lists: merge both sides.
  - Pure formatting/whitespace conflicts.
- **Non-trivial — STOP:**
  - Business logic conflicts.
  - The same code zone modified on both sides with different intent.

  Present the conflicting hunks (file, both versions, what each side was trying to do) and ask the user how to resolve. Do not guess. Do not abort the merge unless the user asks; if they do, run `git merge --abort` and go to step 6.

Environment branches often carry other features' unmerged work: when a conflict involves code that only exists on the environment branch, keep that code and add the feature's change around it, unless the intents clash — then it is non-trivial.

After resolving every conflict: `git add <files>` then `git commit --no-edit`.

### 5. Push the Environment Branch

Show the summary first: environment branch, feature branch, merge commit, conflicts resolved and how.

Unless `--no-push` was given, push the merge to the environment branch:

```bash
git push origin HEAD:<env-branch>
```

**Never use `--force` or `--force-with-lease` on an environment branch.** If the push is rejected because the remote moved, fetch again and restart from step 3 — do not overwrite the remote.

### 6. Return to the Feature Branch

```bash
git switch <feature-branch>
```

Always come back to the feature branch, including when the process stopped or was aborted, once the merge is either committed or aborted. If a merge is still in progress because the user is resolving a conflict, stay on it and say how to finish (`git add`, `git commit --no-edit`, push, then `git switch <feature-branch>`).

### 7. Report

- Environment branch and feature branch used.
- Conflicts encountered: which were auto-resolved (and how), which required the user.
- Merge commit SHA and push status (pushed, skipped with `--no-push`, or rejected).
- The branch HEAD is now on.

## Notes

- The environment branch is never rebased, never reset and never force-pushed: other features live on it.
- The feature branch is left untouched — the merge only exists on the environment branch.
- When in doubt about a conflict's triviality, treat it as non-trivial.
