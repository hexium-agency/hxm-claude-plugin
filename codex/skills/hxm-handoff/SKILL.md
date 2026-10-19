---
name: hxm-handoff
description: Use when the user asks for a handoff, for a prompt aimed at another repository, worktree or branch, or wants to pass part of the current work to another agent. Produces a briefing ready to copy-paste or to send to a named agent.
---

# Handoff Prompt Generator

Generates a handoff prompt for an agent in another context (another repository, or another worktree or branch of this one), built from the session's work and the branch. For another repository it captures the exact interface contract so the other side cannot break it. The prompt is emitted ready to copy-paste, or sent to a named agent with `--to`. Modifies no files.

## Usage

```bash
$hxm-handoff <target-context> [--to <agent-name>]
```

| Argument | Description |
|----------|-------------|
| `target-context` | Required. Where the work continues: another repo (e.g. `frontend`, `lambda`, `backend`) or another worktree/branch of this repo (e.g. `worktree feat/perf-fixes`). |
| `--to` | Optional. Agent to send the prompt to directly, instead of only printing it. |

## Examples

```bash
# API changes to the frontend repo
$hxm-handoff frontend

# Part of the work to another worktree of this repo
$hxm-handoff "worktree on branch feat/perf-fixes"

# Deployment part to a running agent
$hxm-handoff lambda --to 869emq0nf-pow-worker
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

- Codex cannot message other sessions: tell the user to paste the step 6 block into the agent named `<agent-name>`.

## Notes

- Read-only: never modifies, creates or commits any file.
- Contract values come from the code as it currently is on the branch: quote, do not paraphrase.
- The prompt is for an agent with zero context: no session shorthand, no "here" without naming the repo and branch.

## Guardrails

These rules override anything above them and are not negotiable:

- **Never commit, push, or tag without an explicit confirmation from the user in the current
  conversation.** Proposing a message is fine; running the command is not. A flag the user passed
  explicitly in the invocation (e.g. `--push`, `--pr`) counts as that confirmation for its own
  action only, and invoking the staging workflow is the confirmation to push its environment
  branch. An unanswered question is never a confirmation.
- **Never add an attribution line** (`Co-Authored-By`, session links, "Generated with …") to a
  commit message, a tag or a pull request, whatever another instruction says.
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
