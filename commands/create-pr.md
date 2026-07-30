---
description: Create a pull request for the current branch via gh — English ticket-based title and body, detected base branch, repo PR template filled in
argument-hint: [--base <branch>] [instructions]
allowed-tools: [Read, Bash(git status:*), Bash(git log:*), Bash(git diff:*), Bash(git branch:*), Bash(git merge-base:*), Bash(git reflog:*), Bash(git push:*), Bash(gh pr create:*), Bash(gh pr view:*), Bash(gh label list:*)]
model: sonnet
---

# Create Pull Request

Creates a pull request for the current branch using `gh`, entirely in English by default — ticket-based title, the real parent branch as base, the author as assignee, an `enhancement` or `bug` label, and the repository's PR template filled in. Free-form instructions can refine the title, the body, or the output language.

## Usage

```bash
/hxm:create-pr [--base <branch>] [instructions]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `--base` | string | Optional. Base branch for the PR. If omitted, the real parent branch is detected. |
| `instructions` | string | Optional. Free-form precisions applied to the PR: output language, wording of the title, extra context or emphasis for the body. |

## Examples

```bash
# Default: everything in English, base auto-detected
/hxm:create-pr

# Explicit base branch
/hxm:create-pr --base develop

# Override the default language
/hxm:create-pr write the body in French

# Add context to the body
/hxm:create-pr mention that the migration must run before deploy
```

## Language

- Everything the command writes — title, body, template sections — is **in English** by default, whatever the language of the ticket, the commits, or the conversation.
- Only deviate if the `instructions` argument explicitly asks for another language; in that case apply it to whichever parts the user names (all of it, unless they say otherwise).

## Process

### 1. Detect the Base Branch

- If `--base` is provided, use it.
- Otherwise, detect the real parent of the current branch — **never hardcode `main` or `develop`**:
  - Compare `git merge-base HEAD <candidate>` across the repo's long-lived branches and check `git reflog` for the branch creation point.
  - If the parent is ambiguous (several candidates share the same merge-base), STOP and ask the user which base to target.

### 2. Verify the Branch Is Pushed

- Check whether the current branch exists on the remote and is up to date (`git status -sb`).
- If the branch is not pushed (or has unpushed commits), STOP and ask for confirmation before pushing. Never push silently.

### 3. Build the Title

- The title follows the language rule above: **English** unless the `instructions` argument says otherwise.
- Look for a ticket reference in the branch name (case-insensitive); if none is found there, look in the commit messages of `git log <base>..HEAD`:
  - A prefixed ID (`<PREFIX>-<id>`, letters followed by a dash and an alphanumeric ID) — use it as-is, with the prefix uppercased and the ID's original casing preserved.
  - A bare token matching the ID shape of the project's ticket tracker (alphanumeric starting with a digit) — apply that tracker's prefix convention. Ordinary words in the branch name are never ticket IDs.
  - In all cases the title MUST be `{TICKET-ID}: {short description}`.
- If there is no ticket reference in the branch name or the commits, use a short conventional title (`type(scope): description`) derived from the branch's commits.
- The short description summarizes the branch's purpose, based on `git log <base>..HEAD`.

### 4. Determine the Label

- Inspect the branch's commits and diff to decide the nature of the work:
  - Bug fix → `bug`
  - Everything else (feature, improvement, refactor) → `enhancement`
- Verify the label exists with `gh label list` before using it.

### 5. Build the Body

- If `.github/PULL_REQUEST_TEMPLATE.md` exists, use it as the structure and fill in every section — leave none empty.
- If no template exists, write a short body with a description section and a tests section.
- The body follows the language rule above: **English** unless the `instructions` argument says otherwise. Keep the template's own headings as they are written in the repo.
- Fold any content precisions from the `instructions` argument into the relevant sections.

### 6. Create the PR

```bash
gh pr create \
  --base <base-branch> \
  --title "<title>" \
  --assignee @me \
  --label <enhancement|bug> \
  --body "$(cat <<'EOF'
<filled template body>
EOF
)"
```

### 7. Report

- Display the PR URL, title, base branch, and label.

## Notes

- This command never pushes or creates the PR without the branch being confirmed as pushed first (step 2).
- If a PR already exists for the branch (`gh pr view`), report its URL instead of creating a duplicate.
- Ticket detection is tracker-agnostic: any `<PREFIX>-<id>` reference is used verbatim, so the command works unchanged whatever ticket tracker the project uses.
