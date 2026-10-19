---
name: staging
description: Merge the current branch into an environment branch (staging by default) and push it to deploy — resolves trivial conflicts, stops on non-trivial ones, never rebases or force-pushes
arguments: [<env-branch>] [--no-push]
trigger: Use when the user asks to merge the current branch into staging or another deployment environment branch, send it to staging, or deploy it there. Merges without rebasing, resolves trivial conflicts, stops on business-logic ones and never force-pushes.
requires: none
---

# Merge into an Environment Branch

Merges the current feature branch into an environment branch (`staging` by default) and pushes it so the environment deploys the feature. The merge happens on a detached checkout of the remote environment branch, so no local copy of it is created or rewritten. Trivial conflicts are auto-resolved, non-trivial ones stop the process. The environment branch is never rebased, reset or force-pushed (other features live on it). Running the command is the consent to push the environment branch.

## Usage

```bash
{{command:staging}} [<env-branch>] [--no-push]
```

| Argument | Description |
|----------|-------------|
| `env-branch` | Optional. Environment branch to merge into. Defaults to `staging`, or to the one the project's conventions name. |
| `--no-push` | Stop after the merge and show the summary, without pushing. |

## Examples

```bash
# Merge into staging and push
{{command:staging}}

# Other environment branch, without pushing
{{command:staging}} preprod --no-push
```

## Process

### 1. Determine the Environment Branch

- Use `env-branch` if provided.
- Otherwise look for the project's convention: deployment workflows (`.github/workflows/`), `CLAUDE.md`, `README`, remote branches (`git branch -r`). Use `staging` when it exists on the remote and nothing says otherwise.
- None determinable, or several candidates: STOP and ask the user.

**Guard — refuse and STOP** when the environment branch is a production or integration branch (`main`, `master`, `develop`, `production`, `prod`, `release`, `release/*`, `live`), the base branch of the current branch's pull request, or the current branch itself. Never merge into such a branch with this command, even if the user insists: tell them to do it by hand.

### 2. Check the Starting Point

```bash
git status
git branch --show-current
```

- Working tree must be clean, else STOP and ask how to handle pending changes.
- HEAD must be on a named branch (the feature branch); remember it for step 6.
- Feature branch commits not pushed to its own remote branch: say so, they will reach the environment without being on the feature branch's remote.

### 3. Fetch and Check Out the Environment Branch

```bash
git fetch origin
git switch --detach origin/<env-branch>
```

If `origin/<env-branch>` does not exist, STOP and tell the user, never create an environment branch.

### 4. Merge the Feature Branch

```bash
git merge --no-ff <feature-branch>
```

Merge only: **never rebase the feature branch onto the environment branch, never rebase the environment branch**.

Classify each conflict with the {{command:rebase}} rules:

- **Trivial — resolve automatically:**
  - Lockfiles (`composer.lock`, `package-lock.json`, `yarn.lock`, ...): re-generate or take the combination keeping both sides' dependency changes.
  - Import/use statement lists: merge both sides.
  - Pure formatting/whitespace.
- **Non-trivial — STOP:** business logic conflicts, or the same code zone modified on both sides with different intent. Present the conflicting hunks (file, both versions, what each side intended) and ask the user how to resolve. Do not guess. Do not abort the merge unless the user asks; if so, run `git merge --abort` and go to step 6.

Environment branches often carry other features' unmerged work: when a conflict involves code existing only on the environment branch, keep that code and add the feature's change around it, unless the intents clash (then non-trivial). When in doubt about triviality, treat it as non-trivial.

After resolving all conflicts: `git add <files>` then `git commit --no-edit`.

### 5. Push the Environment Branch

Show the summary first: environment branch, feature branch, merge commit, conflicts resolved and how.

Unless `--no-push`:

```bash
git push origin HEAD:<env-branch>
```

**Never use `--force` or `--force-with-lease` on an environment branch.** If the push is rejected because the remote moved, fetch again and restart from step 3, never overwrite the remote.

### 6. Return to the Feature Branch

```bash
git switch <feature-branch>
```

Always come back, including when the process stopped or was aborted, once the merge is committed or aborted. If a merge is still in progress because the user is resolving a conflict, stay on it and say how to finish (`git add`, `git commit --no-edit`, push, then `git switch <feature-branch>`).

### 7. Report

- Environment branch and feature branch used.
- Conflicts: which were auto-resolved (and how), which required the user.
- Merge commit SHA and push status (pushed, skipped with `--no-push`, or rejected).
- The branch HEAD is now on.

The feature branch is left untouched: the merge only exists on the environment branch.
