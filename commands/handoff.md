---
description: Generate a handoff prompt for an agent working in another repo, worktree or branch, based on the work done in the current session and branch — copy-paste ready, or sent directly to a named agent
argument-hint: <target-context> [--to <agent-name>]
allowed-tools: [Read, Grep, Glob, Bash(git log:*), Bash(git diff:*), Bash(git branch:*), Bash(git merge-base:*), Bash(git reflog:*), AskUserQuestion, ListAgents, SendMessage]
model: opus
---

# Handoff Prompt Generator

Generates a handoff prompt for an agent working in another context: another repository, or another worktree or branch of the same repository. The prompt is built from the work done in the current session and branch. When the target is another repository, it captures the exact interface contract so the other side cannot break it. The prompt is either emitted ready to copy-paste, or sent directly to a named agent with `--to`. This command modifies no files.

## Usage

```bash
/hxm:handoff <target-context> [--to <agent-name>]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `target-context` | string | Required. Where the work continues: another repo (e.g. `frontend`, `lambda`, `backend`), or another worktree or branch of this repo (e.g. `worktree feat/perf-fixes`). |
| `--to` | string | Optional. Name of the agent to send the prompt to directly, instead of only printing it. |

## Examples

```bash
# Hand off API changes made here to the frontend repo
/hxm:handoff frontend

# Move part of the session's work to another worktree of this repo
/hxm:handoff "worktree on branch feat/perf-fixes"

# Hand off the deployment part to a running agent
/hxm:handoff lambda --to 869emq0nf-pow-worker
```

## Process

### 1. Gather the Work Done Here

- Review the conversation context: what was implemented or changed in this session, and why.
- If the session holds several independent topics, ask the user which one to hand off before going further. Never guess the topic.
- Complete with the branch history from its real fork point:

```bash
git log $(git merge-base HEAD <parent-branch>)..HEAD --oneline
git diff $(git merge-base HEAD <parent-branch>)..HEAD
```

If the parent branch is unknown, check `git reflog` or ask the user.

### 2. Determine the Target Kind

- **Another repository** — the target is a different codebase that consumes or completes the work. Run step 3.
- **Same repository, another worktree or branch** — the target shares this codebase, so there is no interface contract to protect. Skip step 3 and drop the interface-contract section from the prompt; name instead the branch the target must start from and the commits or files it must build on.

If `target-context` does not make the kind clear, ask the user.

### 3. Extract the Interface Contract (another repository only)

Identify every surface the target repo will interact with, and extract the **exact values from the code** — never approximate or invent:

- API routes: method, path, request payload shape, response payload shape, status codes.
- Events: names, payload schemas.
- Database or data schemas exposed to the other side.
- Enum values, constants, header names, query parameters.

Read the actual source files to quote exact field names, types, and casing.

### 4. Determine the Target-Side Tasks

Derive what the target must do to consume or complete the work, ordered by dependency (what must exist first).

### 5. Generate the Handoff Prompt

Produce the prompt with this exact structure:

1. **Context** — what was done here and why, in a few sentences. Name the repository and branch it comes from.
2. **Interface contract (do not break)** — another repository only: the routes/payloads/events/schemas from step 3, with exact values, in code blocks. For the same repository, replace it with **Starting point**: the branch to start from and the commits or files to build on.
3. **Tasks** — the ordered list of tasks to perform in the target.
4. **Constraints** — the target's conventions if known, and a strict-scope instruction (implement exactly these tasks, nothing more).
5. **Verification** — how to validate the work is complete (what to test, which flows to exercise end-to-end against the contract).

### 6. Output

Emit the generated prompt inside a **single markdown code block** so the user can copy-paste it in one action. Nothing else goes inside the block.

### 7. Send to an Agent (only with `--to`)

- Call `ListAgents` and check that an agent named `<agent-name>` exists. Match case-insensitively; if several agents match, or none does, show the available names and ask the user — never send to a guessed agent.
- Send the prompt from step 5 with `SendMessage` to that agent, unchanged.
- If the send fails, say so and fall back to the copy-paste block from step 6.

## Notes

- This command is read-only: it never modifies, creates, or commits any file.
- Contract values must come from the code as it currently is on the branch — quote them, do not paraphrase.
- The prompt is written for an agent with zero context: no session shorthand, no references to "here" without naming the repo and branch.
