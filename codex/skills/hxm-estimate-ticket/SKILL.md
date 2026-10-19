---
name: hxm-estimate-ticket
description: Use when the user asks to estimate, size or quote a ticket, asks how long a ticket will take, or shares a ClickUp ticket URL with a request such as "estimate this ticket" or "can you estimate this", in any language. Reads the ticket, maps it onto the codebase and returns a reasoned estimate with its risks.
---

# Ticket Effort Estimation

Analyzes a ClickUp ticket and provides a structured estimation of complexity, effort, risks and dependencies.

## Usage

```
$hxm-estimate-ticket <ticket> [--context "additional context"]
```

| Argument | Type | Description |
|----------|------|-------------|
| `ticket` | string | **Required.** Ticket URL or ID (`abc123`, `CU-abc123`, full ClickUp URL) |
| `--context` | string | Additional context for the estimation (e.g., team familiarity, ongoing refactors) |

```bash
$hxm-estimate-ticket https://app.clickup.com/t/abc123
$hxm-estimate-ticket CU-abc123 --context "Team is unfamiliar with the payment module"
```

## Process

### 1. Parse Arguments

1. First positional argument is the ticket identifier; clean it: strip `CU-` and `#` prefixes, extract the ID from a URL (`clickup.com/t/<id>`).
2. Parse `--context`. Free text after the ticket is an implicit `--context`, appended to any explicit one.
3. Images pasted in the invocation are part of the ticket: analyze them with the ticket corpus.

### 2. Retrieve Ticket Information

With the connected ClickUp MCP server:

1. Fetch the ticket by ID (title, description, status, priority, tags, custom fields, subtasks) with whichever task-fetch tool the server exposes. If comments are not included, also call its task-comments tool.
2. **Comment threads:** fetch the thread of every comment that has replies with the threaded-comments tool. If the URL carries `?comment=<id>`, fetch that thread first. A decision in a comment or reply overrides the description.
3. **Attachments:** for every image or PDF, request a download link via the attachment download capability, fetch it immediately and only once into a scratch directory outside the repository, then read it. On failure, list the unreadable attachments and ask the user to paste them.
4. **Linked documents:** retrieve via the document capability (list pages, then fetch each page).
5. Use the list-info capability to understand the project context.

**If the MCP server is unavailable:** tell the user retrieval failed, ask for the ticket details manually, then continue the estimation with them.

### 3. Gather Related Context

1. Use the search capability to find similar completed tasks in the same list or project (similar tags or title keywords). Limit to 5-10 results.
2. Note comparable past tasks and their apparent scope (description length, subtask count, comments volume) to calibrate the estimate.

### 4. Lightweight Codebase Assessment

**Only if a codebase is available in the current working directory:**

1. Detect repository type:
   - Backend: `composer.json`, `artisan`, `requirements.txt`, `pyproject.toml`, `go.mod`
   - Frontend: `package.json`, `src/components/`, `vite.config.*`, `next.config.*`
   - Fullstack: both
2. If the ticket mentions specific areas (modules, files, features), use `Glob` and `Grep` to check whether they exist, how many files the affected area holds, and whether patterns exist to follow or new ones must be established.
3. Check for an existing branch for this ticket: `git branch -a --list "*CU-<ticketId>*"`

### 5. Analyze and Estimate

**Complexity factors:**
- Scope breadth: how many codebase areas are affected?
- Technical depth: new patterns, integrations or architectural changes?
- Requirements clarity: well-defined or ambiguous?
- Dependencies: external systems, APIs or other tickets?
- Testing effort: unit, integration, E2E?
- Risk level: what could go wrong, what are the unknowns?

**Calibration:** use similar past tasks as reference points; factor in whether the work follows or diverges from codebase patterns; incorporate `--context`.

### 6. Present Estimation

---

**Ticket:** `<ticket-title>` (`CU-<ticket-id>`)
**List:** `<list-name>`
**Priority:** `<priority>`

#### Summary

_2-3 sentences on what the ticket requires, from a technical perspective._

#### Complexity: **Simple** | **Medium** | **Complex** | **Very Complex**

| Factor | Assessment |
|--------|------------|
| Scope | _How many areas affected_ |
| Technical depth | _New patterns vs existing patterns_ |
| Requirements clarity | _Clear / Somewhat clear / Ambiguous_ |
| Testing effort | _Low / Medium / High_ |

#### Time Estimate

| Scenario | Estimate |
|----------|----------|
| Optimistic | _Xh (best case, no surprises)_ |
| Realistic | _Xh-Yh (expected)_ |
| Pessimistic | _Yh-Zh (if complications arise)_ |

_Brief justification for the range._

#### Key Risks and Uncertainties

_Bulleted; each item states the risk and its potential time impact. "No significant risks identified." if none._

#### Dependencies and Blockers

_Bulleted external dependencies, other tickets, preconditions. "No dependencies identified." if none._

#### Recommendations

_Optional. 1-3 actionable suggestions to reduce risk or effort (e.g., "Clarify the expected behavior for edge case X before starting", "Consider splitting into two tickets")._

---

## Complexity Scale Reference

| Level | Description | Typical Range |
|-------|-------------|---------------|
| **Simple** | Single area, clear requirements, follows existing patterns, minimal testing | 1h - 4h |
| **Medium** | Few areas, mostly clear requirements, some new logic, moderate testing | 4h - 12h |
| **Complex** | Multiple areas, some ambiguity, new patterns or integrations, significant testing | 12h - 30h |
| **Very Complex** | Cross-cutting concerns, architectural changes, high ambiguity, extensive testing | 30h+ |

Ranges are guidelines: adjust for codebase size, team context and `--context`.

## Notes

- Read-only: modifies no file, does not update the ticket.
- Estimates are rough assessments from available information, not commitments.
- For a full implementation plan, use `$hxm-plan-ticket`.

## Prerequisites

- **ClickUp MCP server** — ticket lookup, comments and metadata. Without it, the skill falls back to details pasted by the user.

Configure these as MCP servers in your own Codex configuration. This plugin ships no credentials
and no MCP configuration.

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
