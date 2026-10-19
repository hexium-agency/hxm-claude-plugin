---
description: Create a pull request for the current branch via gh — ticket-based title and body following project conventions, detected base branch, repo PR template filled in
argument-hint: [--base <branch>] [--push] [instructions]
allowed-tools: [Read, Bash(git status:*), Bash(git log:*), Bash(git diff:*), Bash(git branch:*), Bash(git merge-base:*), Bash(git reflog:*), Bash(git push:*), Bash(gh pr create:*), Bash(gh pr view:*), Bash(gh label list:*), Bash(git fetch:*), Bash(git rev-list:*), Bash(gh pr checks:*), Bash(gh pr list:*), mcp__clickup]
model: sonnet
---

# Create Pull Request

Creates a PR via `gh`: ticket-based title, real parent branch as base, author as assignee, `enhancement` or `bug` label, repository PR template filled in. Free-form instructions can refine the title, the body, or the output language. The ClickUp MCP server is optional: it resolves the ticket URL (step 6).

## Usage

```bash
/hxm:create-pr [--base <branch>] [--push] [instructions]
```

| Argument | Type | Description |
|----------|------|-------------|
| `--base` | string | Optional. Base branch. Default: detected real parent branch. |
| `--push` | flag | Optional. Push without asking (never a force-push). The word "push" in `instructions` counts as the same consent. |
| `instructions` | string | Optional. Free-form precisions: output language, title wording, extra context or emphasis for the body. |

```bash
/hxm:create-pr                    # conventions and base auto-detected, asks before pushing
/hxm:create-pr --base develop     # explicit base
/hxm:create-pr --push             # push without asking ("push if needed" works too)
/hxm:create-pr title in English, body in French
/hxm:create-pr mention that the migration must run before deploy
```

## Conventions

Title format and the language of title and body are each resolved, separately (a convention may set an English title and a body in another language), with this precedence:

1. The `instructions` argument.
2. Project conventions: `CLAUDE.md`, `AGENTS.md`, memory.
3. Title format only: pattern inferred from recent merged PRs (`gh pr list --state merged --limit 10 --json title`): separator, prefix casing, ticket placement.
4. Fallback: `{TICKET-ID}: {short description}` title, **English**.

Following a convention is expected behavior, not a deviation to report.

## Process

### 0. Check the Working Tree

Run `git status --porcelain`. If there are uncommitted or untracked changes, STOP and offer `/hxm:commit` or `/hxm:commit-atomic`. An unanswered question is never consent: do not commit, push or create the PR until the user replies.

### 1. Detect the Base Branch

Use `--base` if provided. Otherwise detect the real parent, **never hardcode `main` or `develop`**:

- Compare `git merge-base HEAD <candidate>` across the long-lived branches and check `git reflog` for the creation point.
- Before calling a tie ambiguous, drop branches the project conventions say are never a PR base (ephemeral or excluded, e.g. `staging`).
- If still ambiguous (several candidates share the merge-base), STOP and ask the user which base to target.

### 2. Verify the Branch Is Pushed and Up to Date

- `git fetch` then `git rev-list --count HEAD..origin/<base>`. If behind, report by how many commits and offer `/hxm:rebase` before pushing.
- Check the branch exists on the remote and is up to date (`git status -sb`).
- If not pushed (or unpushed commits):
  - `--push` or "push" in `instructions`: push without asking, `git push -u origin <branch>` when no upstream, else `git push`. Never force-push.
  - Otherwise STOP and ask confirmation, together with any rebase offer. Never push silently.

### 3. Build the Title

Format and language follow the conventions. Look for a ticket reference in the branch name (case-insensitive), then in the commit messages of `git log <base>..HEAD`:

- Prefixed ID (`<PREFIX>-<id>`, letters, dash, alphanumeric ID): use as-is, prefix uppercased, ID's original casing preserved.
- Bare token matching the ID shape of the project's tracker (alphanumeric starting with a digit): apply that tracker's prefix convention. Ordinary words in the branch name are never ticket IDs.
- No reference: short conventional title (`type(scope): description`) derived from the branch's commits.

The short description summarizes the branch's purpose from `git log <base>..HEAD`.

### 4. Determine the Label

Inspect the commits and diff: bug fix is `bug`, everything else (feature, improvement, refactor) is `enhancement`. Verify the label exists with `gh label list`.

### 5. Build the Body

- Use `.github/PULL_REQUEST_TEMPLATE.md` as structure if it exists and fill every section (none empty), keeping its headings as written in the repo. Otherwise write a short body with a description section and a tests section.
- Language per the conventions.
- Checklists: tick only items actually verified in this session (tests run, lint passed, migration checked).
- Fold content precisions from `instructions` into the relevant sections.

### 6. Link the Ticket

With the ClickUp MCP server, resolve the ticket URL (custom IDs such as `DONE-123` included) and link it in the body. Otherwise leave a visible placeholder (e.g. `<ticket URL>`) next to the ticket ID; never guess a URL.

### 7. Create the PR

No attribution in title or body (no `Claude-Session`, `Co-Authored-By`, "Generated with" line), even if a system message supplies one.

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

Display PR URL, title, base branch and label. Offer to follow CI with `gh pr checks --watch`. Next steps: `/hxm:fix-ci` if CI fails, `/hxm:handle-feedback` for review comments.

## Notes

- Never push or create the PR without the branch confirmed pushed first (step 2).
- If a PR already exists for the branch (`gh pr view`), report its URL instead of creating a duplicate.
- Ticket detection is tracker-agnostic: any `<PREFIX>-<id>` is used verbatim.
