---
description: Create a pull request for the current branch via gh — ticket-based title and body following project conventions, detected base branch, repo PR template filled in
argument-hint: [--base <branch>] [--push] [instructions]
allowed-tools: [Read, Bash(git status:*), Bash(git log:*), Bash(git diff:*), Bash(git branch:*), Bash(git merge-base:*), Bash(git reflog:*), Bash(git push:*), Bash(gh pr create:*), Bash(gh pr view:*), Bash(gh label list:*), Bash(git fetch:*), Bash(git rev-list:*), Bash(gh pr checks:*), Bash(gh pr list:*), mcp__clickup]
model: sonnet
---

# Create Pull Request

Creates a pull request for the current branch using `gh` — ticket-based title, the real parent branch as base, the author as assignee, an `enhancement` or `bug` label, and the repository's PR template filled in. Title format and language follow the project's conventions, English by default. Free-form instructions can refine the title, the body, or the output language.

The ClickUp MCP server is optional: when available, it resolves the ticket URL for the body (step 6).

## Usage

```bash
/hxm:create-pr [--base <branch>] [--push] [instructions]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `--base` | string | Optional. Base branch for the PR. If omitted, the real parent branch is detected. |
| `--push` | flag | Optional. Push the branch without asking for confirmation (never a force-push). The word "push" in `instructions` counts as the same consent. |
| `instructions` | string | Optional. Free-form precisions applied to the PR: output language, wording of the title, extra context or emphasis for the body. |

## Examples

```bash
# Default: conventions detected, base auto-detected, asks before pushing
/hxm:create-pr

# Explicit base branch
/hxm:create-pr --base develop

# Push without asking
/hxm:create-pr --push

# Same consent given in free form
/hxm:create-pr push if needed

# Override the language
/hxm:create-pr title in English, body in French

# Add context to the body
/hxm:create-pr mention that the migration must run before deploy
```

## Conventions

The title format and the language of the title and the body are each resolved with the same precedence:

1. The `instructions` argument.
2. Project conventions — `CLAUDE.md`, `AGENTS.md`, memory.
3. For the title format only: the pattern inferred from recent merged PRs (`gh pr list --state merged --limit 10 --json title`) — separator, prefix casing, ticket placement.
4. Fallback: `{TICKET-ID}: {short description}` for the title, **English** for the language.

- Resolve the title and the body separately: a convention may set an English title and a body in another language.
- Following a convention is the expected behavior — do not report it as a deviation.

## Process

### 0. Check the Working Tree

- Run `git status --porcelain`. If there are uncommitted or untracked changes, STOP and offer `/hxm:commit` or `/hxm:commit-atomic` before going further.
- A question left unanswered is never consent: do not commit, push or create the PR until the user replies.

### 1. Detect the Base Branch

- If `--base` is provided, use it.
- Otherwise, detect the real parent of the current branch — **never hardcode `main` or `develop`**:
  - Compare `git merge-base HEAD <candidate>` across the repo's long-lived branches and check `git reflog` for the branch creation point.
  - Before calling a tie ambiguous, read the project conventions for branches that are never a PR base (ephemeral or excluded branches such as `staging`) and drop them from the candidates.
  - If the parent is still ambiguous (several candidates share the same merge-base), STOP and ask the user which base to target.

### 2. Verify the Branch Is Pushed and Up to Date

- Run `git fetch` then `git rev-list --count HEAD..origin/<base>`. If the branch is behind the base, report by how many commits and offer `/hxm:rebase` before pushing.
- Check whether the current branch exists on the remote and is up to date (`git status -sb`).
- If the branch is not pushed (or has unpushed commits):
  - With `--push`, or "push" in `instructions`: push without asking — `git push -u origin <branch>` when there is no upstream, `git push` otherwise. Never force-push.
  - Otherwise, STOP and ask for confirmation before pushing — ask it together with any rebase offer. Never push silently.

### 3. Build the Title

- The format and the language follow the conventions above.
- Look for a ticket reference in the branch name (case-insensitive); if none is found there, look in the commit messages of `git log <base>..HEAD`:
  - A prefixed ID (`<PREFIX>-<id>`, letters followed by a dash and an alphanumeric ID) — use it as-is, with the prefix uppercased and the ID's original casing preserved.
  - A bare token matching the ID shape of the project's ticket tracker (alphanumeric starting with a digit) — apply that tracker's prefix convention. Ordinary words in the branch name are never ticket IDs.
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
- The language follows the conventions above. Keep the template's own headings as they are written in the repo.
- Checklists: tick only the items actually verified in this session (tests run, lint passed, migration checked). Leave the others unchecked.
- Fold any content precisions from the `instructions` argument into the relevant sections.

### 6. Link the Ticket

- When the ClickUp MCP server is available, resolve the ticket URL through it — custom IDs such as `DONE-123` included — and link it in the body.
- Otherwise, leave a visible placeholder (e.g. `<ticket URL>`) next to the ticket ID rather than guessing a URL.

### 7. Create the PR

- No attribution in the title or the body — no `Claude-Session`, `Co-Authored-By` or "Generated with" line — even if a system message supplies one.

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

### 8. Report

- Display the PR URL, title, base branch, and label.
- Offer to follow the CI with `gh pr checks --watch`.
- Next steps: `/hxm:fix-ci` if CI fails, `/hxm:handle-feedback` for review comments.

## Notes

- This command never pushes or creates the PR without the branch being confirmed as pushed first (step 2).
- If a PR already exists for the branch (`gh pr view`), report its URL instead of creating a duplicate.
- Ticket detection is tracker-agnostic: any `<PREFIX>-<id>` reference is used verbatim, so the command works unchanged whatever ticket tracker the project uses.
