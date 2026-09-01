---
name: handle-feedback
description: Analyze a ClickUp or GitHub review comment against the current branch, implement it if founded, and draft a reply the user can post themselves
arguments: <comment-url-or-file>
trigger: Use when the user brings a ClickUp comment or a GitHub review comment and asks to handle, address or answer it. Checks the feedback against the current branch, implements it when founded, and drafts a reply for the user to post themselves.
requires: clickup, gh
---

# Handle Review Feedback

Retrieves a single review comment (ClickUp or GitHub), assesses whether it is still relevant against the current state of the branch, implements the fix if the feedback is founded, and produces a short draft reply in French that the user can copy — the command never posts anything itself.

## Usage

```bash
{{command:handle-feedback}} <comment-url-or-file>
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `comment-url-or-file` | string | Required. A ClickUp comment deep-link (`...?comment=<id>`), a GitHub review thread URL (`...#discussion_r<id>`), or a path to a local file containing the comment text. |

## Examples

```bash
# ClickUp comment deep-link
{{command:handle-feedback}} "https://app.clickup.com/t/abc123?comment=987654"

# GitHub review thread
{{command:handle-feedback}} "https://github.com/org/repo/pull/42#discussion_r123456789"

# Local file containing the comment
{{command:handle-feedback}} ./feedback.txt
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
- Changes are left uncommitted; use `{{command:commit}}` separately when the user asks.
- If the comment covers several distinct requests, handle each one and give a per-request verdict in the summary.
