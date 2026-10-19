---
name: handle-feedback
description: Analyze a ClickUp or GitHub review comment against the current branch, implement it if founded, and draft a reply the user can post themselves
arguments: [target] [context...] [--all] [--explain] [--peer <session>[,<session>]]
trigger: Use when the user brings a ClickUp comment, a ClickUp task, a GitHub review comment or a pull request and asks to handle, address, explain or answer its feedback, or to check which comments are still pending. Checks each comment against the current branch, implements it when founded, verifies the change, drafts a reply for the user to post themselves and offers to commit.
requires: clickup, gh
---

# Handle Review Feedback

Retrieves review feedback (ClickUp or GitHub), checks it against the current branch, implements and verifies the fix if founded, drafts a short French reply the user can copy, then offers delivery. The command never posts anything itself.

## Usage

```bash
{{command:handle-feedback}} [target] [context...] [--all] [--explain] [--peer <session>[,<session>]]
```

| Argument | Description |
|----------|-------------|
| `target` | Optional. ClickUp comment deep-link (`.../t/<workspace_id>/<task_id>?comment=<id>[&threadedComment=<id>]`), ClickUp task URL or ID (custom IDs such as `DONE-123` included), GitHub review thread URL (`...#discussion_r<id>`), PR URL or number, or path to a local file holding the comment text. When omitted, the ticket comes from the branch name and the PR from `gh pr view`. |
| `context` | Optional free text after the target. A hypothesis to verify (e.g. "not started I think?"), with its own verdict. |
| `--all` | Batch mode: list every comment of the ticket and/or PR with its status, handle each founded one separately. |
| `--explain` | Read-only: explain the comment in the context of the code, implement nothing. |
| `--peer` | Comma-separated peer sessions working on the other side (front/back) of the same ticket. Discovered automatically when omitted (step 3). |

## Examples

```bash
# ClickUp comment deep-link (a threadedComment reply is itself the target)
{{command:handle-feedback}} "https://app.clickup.com/t/2567895/abc123?comment=987654"

# GitHub review thread
{{command:handle-feedback}} "https://github.com/org/repo/pull/42#discussion_r123456789"

# ClickUp task without comment ID: picks the pending comment, or the description
{{command:handle-feedback}} DONE-580

# No target: ticket from the branch name, PR from the current branch
{{command:handle-feedback}}

# Hypothesis to verify
{{command:handle-feedback}} "https://app.clickup.com/t/2567895/abc123?comment=987654" not started I think?

# Every comment of the PR, one verdict and one commit per comment
{{command:handle-feedback}} 42 --all

# Explain without touching the code
{{command:handle-feedback}} "https://app.clickup.com/t/2567895/abc123?comment=987654" --explain

# Ask the backend session when the cause may be on its side
{{command:handle-feedback}} "https://app.clickup.com/t/2567895/abc123?comment=987654" --peer abc123-backend

# Local file containing the comment
{{command:handle-feedback}} ./feedback.txt
```

## Process

### 1. Resolve the Target

1. Parse arguments: the first positional is the `target` if it is a URL, ID, PR number or existing file path; remaining free text is the `context` hypothesis (if it names another session or asks to check the other side, treat it as `--peer`).
2. No `target`: ticket ID from `git branch --show-current` (e.g. `CU-abc123`, `DONE-123`); PR from `gh pr view --json number,url,headRefName`. If neither is found, ask the user.
3. **ClickUp URL:** `https://app.clickup.com/t/<workspace_id>/<task_id|custom_id>?comment=<id>&threadedComment=<id>` (workspace segment may be absent).
   - Pass the workspace ID to every ClickUp MCP call accepting one.
   - Resolve a custom ID to the real task ID before fetching comments.
   - With `threadedComment`, that reply is the target; `comment` is its parent thread.
4. **GitHub URL:** extract owner, repo, PR number, comment ID (`discussion_r<id>`). A bare PR URL or number targets the whole PR.

### 2. Retrieve the Feedback

- **ClickUp:** via the ClickUp MCP server, fetch the task's comments (not the full task) and the target's threaded replies. Fetch the full task only when its description is needed. If the MCP server is unavailable, ask the user to paste the comment.
- **GitHub review comment:** `gh api repos/<owner>/<repo>/pulls/comments/<comment-id>`
- **GitHub PR:** `gh api repos/<owner>/<repo>/pulls/<number>/comments` and `gh api repos/<owner>/<repo>/issues/<number>/comments`
- **File path:** read the file as the comment.

**Always read the whole thread**, every reply in order: a later reply from the PO or client overrides the original request and any option discussed before.

**Attachments:** download images attached to the comment or thread (ClickUp MCP attachment download, or GitHub comment image URLs) and read them. For a video, say so immediately and ask the user for a one-line description of it before investigating.

**Selecting comment(s)** when the target has no comment deep-link, classify each as:

- **Done** — answered, or addressed by a commit posted after it
- **Pending** — posted after the branch's last commit, or unanswered
- **Question** — asks for information, not a change

With `--all`: list every comment with its status, then handle each pending or question comment separately through steps 3 to 6, each with its own verdict. Without `--all`: exactly one pending comment, take it; ticket without comments, treat its description as the feedback without asking; otherwise list comments with status and ask which one.

Capture per comment: author, referenced file/line if any, exact request, thread's final position.

### 3. Assess Relevance Against the Current Branch

- Read the referenced file(s) at their current branch version.
- Check `git log` / `git diff` for commits after the comment that may already address it.
- Verify the `context` hypothesis if given, stating whether it holds, with evidence.
- If the cause may be on the other side (front/back) and a peer session is named or discoverable, ask it before concluding:
  <!-- provider:claude -->
  - Use the sessions from `--peer` or named in the context. Otherwise call `ListAgents` and keep sessions whose name starts with the ticket ID (case-insensitive), excluding this session
  - Send the peer the comment, what this side observed, and the precise question with `SendMessage`, then wait for its answer
  <!-- /provider -->
  <!-- provider:codex -->
  - Codex cannot discover or message other sessions. When a peer session is named, write the question for it as a copy-paste-ready block (the comment, what this side observed, the precise question), ask the user to relay it, then wait for the user to paste the answer
  <!-- /provider -->
- Conclude with exactly one verdict:
  - **Founded** — real and still present on this side.
  - **Already addressed** — a later change resolved it (identify the commit or code).
  - **Not founded / obsolete** — incorrect, based on outdated code, belongs to the other side, or no longer applies.

**`--explain`:** stop here. Explain what the comment asks, what it refers to (`file:line`), and what a fix would involve. Modify no file, then go to step 7.

### 4. Act on the Verdict

- **Founded:** implement the correction strictly within the comment's scope, no refactoring of adjacent code.
- **Already addressed / not founded:** change NO code; explain why with precise `file:line` references.

When several fixes are valid: take the preference stated in the thread first (PO, client, reviewer); if none, present the options and ask the user. Never recommend an option that drops an original constraint of the comment or ticket.

### 5. Verify

Skip when no code changed.

1. Run the tests targeting the changed code and the project's linter.
2. If the local stack (e.g. Sail, Docker Compose) is down and its ports are free, start it detached without asking; ask only when a port is held by another stack.
3. Fix failures caused by the change; report unrelated ones (flaky, pre-existing) separately, unfixed.

### 6. Draft a Reply

**FORBIDDEN: Never reply to, comment on, or resolve the thread on ClickUp or GitHub. The user posts replies themselves.**

If the user provided their own reply (text, or a reply URL to fetch), review it against the code instead: point out every inaccurate or missing statement and give the corrected version.

Otherwise draft a short reply **in French** to copy-paste, matching the verdict: Founded, what changed and where; Already addressed, which commit/code covers it; Not founded, a courteous factual explanation.

### 7. Final Summary

Per comment handled:

- **Comment:** one-line restatement and author (plus the thread's final position if it differs).
- **Hypothesis:** the `context` given and whether it holds, if any.
- **Verdict:** Founded / Already addressed / Not founded, justified with `file:line`.
- **Action taken:** files modified, or "none" with the reason.
- **Verification:** tests and linter results, unrelated failures listed separately.
- **Draft reply (French):** copy-paste-ready, in a code block.

With `--all`, start with the table of every comment and its status. With `--explain`, present only the comment, the explanation and the code references.

### 8. Offer Delivery

Skip with `--explain` or when no file changed.

<!-- provider:claude -->
Use `AskUserQuestion` to ask one question with these options:
<!-- /provider -->
<!-- provider:codex -->
Ask the user one question with these options and wait for the answer:
<!-- /provider -->

- Commit
- Commit and push
- Commit, push, and merge into staging via `{{command:staging}}` — only when a staging branch exists (`git branch -a --list '*staging*'`)

Then commit by following the `{{command:commit}}` procedure (with `--all`, suggest one commit per comment). If HEAD is already on the remote, make a new `fix(...)` commit without asking about amending. Never commit, push, or merge without this explicit choice.

## Notes

- Retrieval only: never write to ClickUp or GitHub. Posting, resolving and reacting are the user's job.
- If a comment covers several distinct requests, handle each and give a per-request verdict in the summary.
