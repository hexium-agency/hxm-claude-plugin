---
name: handoff
description: Generate a copy-paste-ready handoff prompt for a Claude agent working in another repo, based on the work done in the current session and branch
arguments: <target-repo-context>
trigger: Use when the user asks for a handoff, for a prompt aimed at another repository, or wants to pass the current work to an agent working in a different codebase. Produces a copy-paste-ready briefing.
requires: none
---

# Handoff Prompt Generator

Generates a handoff prompt, ready to copy-paste, for a Claude agent launched in another repository. The prompt is built from the work done in the current session and branch, and captures the exact interface contract so the other side cannot break it. This command modifies no files.

## Usage

```bash
{{command:handoff}} <target-repo-context>
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `target-repo-context` | string | Required. The target repo or context the prompt is for (e.g. `frontend`, `lambda`, `backend`). |

## Examples

```bash
# Hand off API changes made here to the frontend team agent
{{command:handoff}} frontend

# Hand off event contract changes to the lambda repo
{{command:handoff}} lambda
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
