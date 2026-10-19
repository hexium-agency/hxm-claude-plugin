---
description: Generate a handoff prompt for an agent working in another repo, worktree or branch, based on the work done in the current session and branch — copy-paste ready, or sent directly to a named agent
argument-hint: <target-context> [--to <agent-name>]
allowed-tools: [Read, Grep, Glob, Bash(git log:*), Bash(git diff:*), Bash(git branch:*), Bash(git merge-base:*), Bash(git reflog:*), AskUserQuestion, ListAgents, SendMessage]
model: opus
---

# Handoff Prompt Generator

Generates a handoff prompt for an agent in another context (another repository, or another worktree or branch of this one), built from the session's work and the branch. For another repository it captures the exact interface contract so the other side cannot break it. The prompt is emitted ready to copy-paste, or sent to a named agent with `--to`. Modifies no files.

## Usage

```bash
/hxm:handoff <target-context> [--to <agent-name>]
```

| Argument | Description |
|----------|-------------|
| `target-context` | Required. Where the work continues: another repo (e.g. `frontend`, `lambda`, `backend`) or another worktree/branch of this repo (e.g. `worktree feat/perf-fixes`). |
| `--to` | Optional. Agent to send the prompt to directly, instead of only printing it. |

## Examples

```bash
# API changes to the frontend repo
/hxm:handoff frontend

# Part of the work to another worktree of this repo
/hxm:handoff "worktree on branch feat/perf-fixes"

# Deployment part to a running agent
/hxm:handoff lambda --to 869emq0nf-pow-worker
```

## Process

### 1. Gather the Work Done Here

- Review the conversation: what was implemented or changed, and why.
- Several independent topics in the session: ask which one to hand off, never guess.
- Complete with the branch history from its real fork point:

```bash
git log $(git merge-base HEAD <parent-branch>)..HEAD --oneline
git diff $(git merge-base HEAD <parent-branch>)..HEAD
```

Parent branch unknown: check `git reflog` or ask the user.

### 2. Determine the Target Kind

- **Another repository** (a different codebase consuming or completing the work): run step 3.
- **Same repository, another worktree or branch** (shared codebase, no contract to protect): skip step 3, drop the interface-contract section, and instead name the branch the target must start from and the commits or files to build on.

If `target-context` does not make the kind clear, ask the user.

### 3. Extract the Interface Contract (another repository only)

Identify every surface the target interacts with and extract the **exact values from the code**, never approximate or invent. Read the source files to quote exact field names, types and casing:

- API routes: method, path, request and response payload shapes, status codes.
- Events: names, payload schemas.
- Database or data schemas exposed to the other side.
- Enum values, constants, header names, query parameters.

### 4. Determine the Target-Side Tasks

Derive what the target must do to consume or complete the work, ordered by dependency (what must exist first).

### 5. Generate the Handoff Prompt

Exact structure:

1. **Context** — what was done here and why, in a few sentences; name the repository and branch it comes from.
2. **Interface contract (do not break)** — another repository only: the step 3 routes/payloads/events/schemas with exact values, in code blocks. Same repository: replace with **Starting point** (branch to start from, commits or files to build on).
3. **Tasks** — ordered list of tasks in the target.
4. **Constraints** — the target's conventions if known, and a strict-scope instruction (implement exactly these tasks, nothing more).
5. **Verification** — how to validate completion (what to test, which flows to exercise end-to-end against the contract).

### 6. Output

Emit the prompt inside a **single markdown code block** for one-action copy-paste. Nothing else goes inside the block.

### 7. Send to an Agent (only with `--to`)

- Call `ListAgents` and check an agent named `<agent-name>` exists (case-insensitive). If several match, or none does, show the available names and ask the user, never send to a guessed agent.
- Send the step 5 prompt unchanged with `SendMessage`.
- If the send fails, say so and fall back to the step 6 block.

## Notes

- Read-only: never modifies, creates or commits any file.
- Contract values come from the code as it currently is on the branch: quote, do not paraphrase.
- The prompt is for an agent with zero context: no session shorthand, no "here" without naming the repo and branch.
