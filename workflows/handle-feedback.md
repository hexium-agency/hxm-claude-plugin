---
name: handle-feedback
description: Analyze a ClickUp or GitHub review comment against the current branch, implement it if founded, and draft a reply the user can post themselves
arguments: [target] [context...] [--all] [--explain] [--peer <session>[,<session>]]
trigger: Use when the user brings a ClickUp comment, a ClickUp task, a GitHub review comment or a pull request and asks to handle, address, explain or answer its feedback, or to check which comments are still pending. Checks each comment against the current branch, implements it when founded, verifies the change, drafts a reply for the user to post themselves and offers to commit.
requires: clickup, gh
---

# Handle Review Feedback

Retrieves review feedback (ClickUp or GitHub), assesses whether it is still relevant against the current state of the branch, implements and verifies the fix if the feedback is founded, produces a short draft reply in French that the user can copy, then offers to deliver the change. The command never posts anything itself.

## Usage

```bash
{{command:handle-feedback}} [target] [context...] [--all] [--explain] [--peer <session>[,<session>]]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `target` | string | Optional. A ClickUp comment deep-link (`.../t/<workspace_id>/<task_id>?comment=<id>[&threadedComment=<id>]`), a ClickUp task URL or ID (including custom IDs such as `DONE-123`), a GitHub review thread URL (`...#discussion_r<id>`), a PR URL or number, or a path to a local file containing the comment text. When omitted, the ticket is resolved from the branch name and the PR from `gh pr view`. |
| `context` | string | Optional free text after the target. Treated as a hypothesis to verify (e.g., "not started I think?", "related to what we just merged?"), with its own verdict. |
| `--all` | flag | Batch mode. Lists every comment of the ticket and/or PR with its status, and handles each founded one separately. |
| `--explain` | flag | Read-only mode. Explains the comment in the context of the code without implementing anything. |
| `--peer` | string | Comma-separated names of peer sessions working on the other side (front/back) of the same ticket. Discovered automatically when omitted (see step 3). |

## Examples

```bash
# ClickUp comment deep-link
{{command:handle-feedback}} "https://app.clickup.com/t/2567895/abc123?comment=987654"

# ClickUp threaded reply: the reply is the target
{{command:handle-feedback}} "https://app.clickup.com/t/2567895/DONE-406?comment=987654&threadedComment=1200960000021825"

# GitHub review thread
{{command:handle-feedback}} "https://github.com/org/repo/pull/42#discussion_r123456789"

# ClickUp task without a comment ID: picks the pending comment, or the description
{{command:handle-feedback}} DONE-580

# No target: ticket from the branch name, PR from the current branch
{{command:handle-feedback}}

# Hypothesis to verify
{{command:handle-feedback}} "https://app.clickup.com/t/2567895/abc123?comment=987654" not started I think?

# Every comment of the PR, one verdict and one commit per comment
{{command:handle-feedback}} 42 --all

# Explain a comment without touching the code
{{command:handle-feedback}} "https://app.clickup.com/t/2567895/abc123?comment=987654" --explain

# Ask the backend session when the cause may be on its side
{{command:handle-feedback}} "https://app.clickup.com/t/2567895/abc123?comment=987654" --peer abc123-backend

# Local file containing the comment
{{command:handle-feedback}} ./feedback.txt
```

## Process

### 1. Resolve the Target

1. Parse the arguments:
   - The first positional argument is the `target` when it is a URL, an ID, a PR number, or an existing file path
   - Any remaining free text is the `context` hypothesis. When it names another session or asks to check the other
     side, treat it as `--peer`
   - `--all`, `--explain`, `--peer` as documented above
2. When `target` is omitted, resolve it from the branch:
   - Ticket: extract the ticket ID from `git branch --show-current` (e.g., `CU-abc123`, `DONE-123`)
   - PR: `gh pr view --json number,url,headRefName` for the current branch
   - If neither is found, ask the user for the target
3. **ClickUp URL format:** `https://app.clickup.com/t/<workspace_id>/<task_id|custom_id>?comment=<id>&threadedComment=<id>`
   (the workspace segment may be absent)
   - Pass the workspace ID to every ClickUp MCP call that accepts one
   - Resolve a custom ID (e.g., `DONE-123`) to the real task ID before fetching comments
   - When `threadedComment` is present, that reply is the target; `comment` is its parent thread
4. **GitHub URL:** extract the owner, repo, PR number, and comment ID (`discussion_r<id>`). A bare PR URL or number
   targets the whole PR

### 2. Retrieve the Feedback

- **ClickUp:** using the connected ClickUp MCP server, fetch the task's comments rather than the full task, and the
  threaded replies of the target comment. Fetch the full task only when its description is needed. If the MCP
  server is unavailable, ask the user to paste the comment text.
- **GitHub review comment:**

```bash
gh api repos/<owner>/<repo>/pulls/comments/<comment-id>
```

- **GitHub PR:** fetch the review comments and the conversation comments:

```bash
gh api repos/<owner>/<repo>/pulls/<number>/comments
gh api repos/<owner>/<repo>/issues/<number>/comments
```

- **File path:** read the file content as the comment.

**Always read the whole thread** before proposing anything: every reply, in order. A later reply from the PO or the
client overrides the original request and any option discussed before it.

**Attachments:** download the images attached to the comment or its thread with the ClickUp MCP server's
attachment download capability (or from the GitHub comment's image URLs), then read them. If a video is attached,
say so immediately and ask the user for a one-line description of what it shows before investigating.

**Selecting the comment(s)** when the target has no comment deep-link:

- Classify each comment with a status:
  - **Done** — answered, or addressed by a commit posted after it
  - **Pending** — posted after the last commit on the branch, or left unanswered
  - **Question** — asks for information rather than a change
- With `--all`: list every comment with its status, then handle each pending or question comment separately
  through steps 3 to 6, each with its own verdict
- Without `--all`:
  - Exactly one pending comment: take it
  - The ticket has no comments: treat the ticket description as the feedback, without asking
  - Otherwise: list the comments with their status and ask the user which one to handle

Capture for each comment: the author, the referenced file/line if any, the exact request, and the thread's final
position.

### 3. Assess Relevance Against the Current Branch

Compare the feedback with the current state of the code:

- Read the file(s) the comment refers to, at their current version on the branch.
- Check `git log` / `git diff` for commits made after the comment that may already address it.
- If a `context` hypothesis was given, verify it and state whether it holds, with evidence.
- If the cause may be on the other side (front/back) and a peer session is named or discoverable, ask it before
  concluding:
  <!-- provider:claude -->
  - Use the sessions given by `--peer` or named in the context. Otherwise call `ListAgents` and keep the sessions
    whose name starts with the ticket ID (case-insensitive), excluding this session
  - Send the peer the comment, what this side observed, and the precise question with `SendMessage`, then wait for
    its answer
  <!-- /provider -->
  <!-- provider:codex -->
  - Codex cannot discover or message other sessions. When a peer session is named, write the question for it as a
    copy-paste-ready block (the comment, what this side observed, the precise question) and ask the user to relay
    it, then wait for the user to paste the answer
  <!-- /provider -->
- Conclude with exactly one verdict:
  - **Founded** — the issue is real and still present on this side.
  - **Already addressed** — a later change resolved it (identify the commit or code).
  - **Not founded / obsolete** — the feedback is incorrect, based on outdated code, belongs to the other side, or no
    longer applies.

**With `--explain`:** stop after this step. Explain what the comment asks, what it refers to in the code
(`file:line`), and what a fix would involve. Do not modify any file, then go to step 7.

### 4. Act on the Verdict

- **Founded:** implement the correction. Stay strictly within the scope of the comment — do not refactor adjacent
  code.
- **Already addressed / not founded:** do NOT change any code. Explain why, with precise code references
  (`file:line`).

When several fixes are valid:

- Take the preference stated in the thread first (PO, client, or reviewer reply).
- If none is stated, present the options and ask the user. Never recommend an option that drops one of the original
  constraints of the comment or the ticket.

### 5. Verify

Skip this step when no code was changed.

1. Run the tests targeting the changed code and the project's linter.
2. If the local stack (e.g., Sail, Docker Compose) is down and its ports are free, start it detached without asking.
   Ask the user only when a port is already held by another stack.
3. Fix failures caused by the change. Report failures unrelated to the change (flaky tests, pre-existing failures)
   separately, without fixing them.

### 6. Draft a Reply

**FORBIDDEN: Never reply to, comment on, or resolve the thread on ClickUp or GitHub. The user posts replies themselves.**

If the user provided their own reply (text, or a reply URL to fetch), review it against the code instead of drafting
a new one: point out every inaccurate or missing statement and give the corrected version.

Otherwise, provide a short draft reply **in French** that the user can copy-paste, matching the verdict:

- Founded: what was changed and where.
- Already addressed: which commit/code already covers it.
- Not founded: a courteous factual explanation.

### 7. Final Summary

Present, per comment handled:

- **Comment:** one-line restatement of the feedback and its author (and the thread's final position if it differs).
- **Hypothesis:** the `context` given and whether it holds, when one was given.
- **Verdict:** Founded / Already addressed / Not founded, with justification (`file:line` references).
- **Action taken:** files modified, or "none" with the reason.
- **Verification:** tests and linter results, with unrelated failures listed separately.
- **Draft reply (French):** the copy-paste-ready text, in a code block.

With `--all`, start with the table of every comment and its status. With `--explain`, present only the comment, the
explanation, and the code references.

### 8. Offer Delivery

Skip this step with `--explain` or when no file was changed.

<!-- provider:claude -->
Use `AskUserQuestion` to ask one question with these options:
<!-- /provider -->
<!-- provider:codex -->
Ask the user one question with these options and wait for the answer:
<!-- /provider -->

- Commit
- Commit and push
- Commit, push, and merge into staging via `{{command:staging}}` — only when a staging branch exists
  (`git branch -a --list '*staging*'`)

Then:

- Commit by following the `{{command:commit}}` procedure. With `--all`, suggest one commit per comment.
- If HEAD is already on the remote, make a new `fix(...)` commit. Do not ask about amending.
- Never commit, push, or merge without this explicit choice.

## Notes

- This command never writes to ClickUp or GitHub — retrieval only. Posting, resolving, and reacting are the user's job.
- Nothing is committed or pushed until the user picks a delivery option in step 8.
- If a comment covers several distinct requests, handle each one and give a per-request verdict in the summary.
- `--explain` is read-only: no file is modified and no delivery is offered.
