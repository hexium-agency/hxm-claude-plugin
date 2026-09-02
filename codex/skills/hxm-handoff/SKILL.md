---
name: hxm-handoff
description: Use when the user asks for a handoff, for a prompt aimed at another repository, or wants to pass the current work to an agent working in a different codebase. Produces a copy-paste-ready briefing.
---

# Handoff Prompt Generator

Generates a handoff prompt, ready to copy-paste, for a Claude agent launched in another repository. The prompt is built from the work done in the current session and branch, and captures the exact interface contract so the other side cannot break it. This command modifies no files.

## Usage

```bash
$hxm-handoff <target-repo-context>
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `target-repo-context` | string | Required. The target repo or context the prompt is for (e.g. `frontend`, `lambda`, `backend`). |

## Examples

```bash
# Hand off API changes made here to the frontend team agent
$hxm-handoff frontend

# Hand off event contract changes to the lambda repo
$hxm-handoff lambda
```

## Process

### 1. Gather the Work Done Here

- Review the conversation context: what was implemented or changed in this session, and why.
- Complete with the branch history from its real fork point:

```bash
git log $(git merge-base HEAD <parent-branch>)..HEAD --oneline
git diff $(git merge-base HEAD <parent-branch>)..HEAD
```

If the parent branch is unknown, check `git reflog` or ask the user.

### 2. Extract the Interface Contract

Identify every surface the target repo will interact with, and extract the **exact values from the code** — never approximate or invent:

- API routes: method, path, request payload shape, response payload shape, status codes.
- Events: names, payload schemas.
- Database or data schemas exposed to the other side.
- Enum values, constants, header names, query parameters.

Read the actual source files to quote exact field names, types, and casing.

### 3. Determine the Target-Side Tasks

Derive what the target repo must do to consume or complete the work, ordered by dependency (what must exist first).

### 4. Generate the Handoff Prompt

Produce the prompt with this exact structure:

1. **Context** — what was done here and why, in a few sentences.
2. **Interface contract (do not break)** — the routes/payloads/events/schemas from step 2, with exact values, in code blocks.
3. **Tasks** — the ordered list of tasks to perform in the target repo.
4. **Constraints** — the target repo's conventions if known, and a strict-scope instruction (implement exactly these tasks, nothing more).
5. **Verification** — how to validate the work is complete (what to test, which flows to exercise end-to-end against the contract).

### 5. Output

Emit the generated prompt inside a **single markdown code block** so the user can copy-paste it in one action. Nothing else goes inside the block.

## Notes

- This command is read-only: it never modifies, creates, or commits any file.
- Contract values must come from the code as it currently is on the branch — quote them, do not paraphrase.
- The prompt is written for an agent with zero context: no session shorthand, no references to "here" without naming the repo.

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
