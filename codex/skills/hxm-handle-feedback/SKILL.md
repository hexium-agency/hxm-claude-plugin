---
name: hxm-handle-feedback
description: Use when the user brings a ClickUp comment or a GitHub review comment and asks to handle, address or answer it. Checks the feedback against the current branch, implements it when founded, and drafts a reply for the user to post themselves.
---

# Handle Review Feedback

Retrieves a single review comment (ClickUp or GitHub), assesses whether it is still relevant against the current state of the branch, implements the fix if the feedback is founded, and produces a short draft reply in French that the user can copy — the command never posts anything itself.

## Usage

```bash
$hxm-handle-feedback <comment-url-or-file>
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `comment-url-or-file` | string | Required. A ClickUp comment deep-link (`...?comment=<id>`), a GitHub review thread URL (`...#discussion_r<id>`), or a path to a local file containing the comment text. |

## Examples

```bash
# ClickUp comment deep-link
$hxm-handle-feedback "https://app.clickup.com/t/abc123?comment=987654"

# GitHub review thread
$hxm-handle-feedback "https://github.com/org/repo/pull/42#discussion_r123456789"

# Local file containing the comment
$hxm-handle-feedback ./feedback.txt
```

## Process

### 1. Retrieve the Comment

- **ClickUp URL:** extract the task ID and comment ID from the URL. Use the connected ClickUp MCP server to fetch the task's comments and locate the one matching the comment ID. If the MCP server is unavailable, ask the user to paste the comment text.
- **GitHub URL:** extract the owner, repo, PR number, and comment ID (`discussion_r<id>`), then fetch it:

```bash
gh api repos/<owner>/<repo>/pulls/comments/<comment-id>
```

  Also fetch the thread replies if any, to understand the full discussion context.
- **File path:** read the file content as the comment.

Capture the comment author, the referenced file/line if any, and the exact request.

### 2. Assess Relevance Against the Current Branch

Compare the feedback with the current state of the code:

- Read the file(s) the comment refers to, at their current version on the branch.
- Check `git log` / `git diff` for commits made after the comment that may already address it.
- Conclude with exactly one verdict:
  - **Founded** — the issue is real and still present.
  - **Already addressed** — a later change resolved it (identify the commit or code).
  - **Not founded / obsolete** — the feedback is incorrect, based on outdated code, or no longer applies.

### 3. Act on the Verdict

- **Founded:** implement the correction. Stay strictly within the scope of the comment — do not refactor adjacent code.
- **Already addressed / not founded:** do NOT change any code. Explain why, with precise code references (`file:line`).

### 4. Draft a Reply

**FORBIDDEN: Never reply to, comment on, or resolve the thread on ClickUp or GitHub. The user posts replies themselves.**

Instead, provide a short draft reply **in French** that the user can copy-paste, matching the verdict:

- Founded: what was changed and where.
- Already addressed: which commit/code already covers it.
- Not founded: a courteous factual explanation.

### 5. Final Summary

Present:

- **Comment:** one-line restatement of the feedback and its author.
- **Verdict:** Founded / Already addressed / Not founded, with justification (`file:line` references).
- **Action taken:** files modified, or "none" with the reason.
- **Draft reply (French):** the copy-paste-ready text, in a code block.

## Notes

- This command never writes to ClickUp or GitHub — retrieval only. Posting, resolving, and reacting are the user's job.
- Changes are left uncommitted; use `$hxm-commit` separately when the user asks.
- If the comment covers several distinct requests, handle each one and give a per-request verdict in the summary.

## Prerequisites

- **ClickUp MCP server** — ticket lookup, comments and metadata. Without it, the skill falls back to details pasted by the user.
- **GitHub CLI (`gh`)**, authenticated against the repository remote.

Configure these as MCP servers in your own Codex configuration. This plugin ships no credentials
and no MCP configuration.

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
