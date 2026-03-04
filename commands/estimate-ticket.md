---
description: Estimate complexity and effort for a ClickUp ticket
allowed-tools: [Read, Glob, Grep, Bash(git branch:*), mcp__clickup__getTaskById, mcp__clickup__searchTasks, mcp__clickup__getListInfo, mcp__clickup__readDocument]
argument-hint: <ticket> [--context "additional context"]
model: sonnet
---

# /hxm:estimate-ticket - Ticket Effort Estimation

Analyzes a ClickUp ticket and provides a structured estimation of complexity, effort, risks, and dependencies.

## Usage

```
/hxm:estimate-ticket <ticket> [--context "additional context"]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `ticket` | string | **Required.** Ticket URL or ID (e.g., `abc123`, `CU-abc123`, or full ClickUp URL) |
| `--context` | string | Additional context to consider during estimation (e.g., team familiarity, ongoing refactors) |

## Examples

```bash
# Estimate a ticket by ID
/hxm:estimate-ticket abc123

# Estimate from a full URL
/hxm:estimate-ticket https://app.clickup.com/t/abc123

# Estimate with additional context
/hxm:estimate-ticket CU-abc123 --context "Team is unfamiliar with the payment module"
```

## Process

### 1. Parse Arguments

1. Extract the ticket identifier from the first positional argument
2. Clean the ticket ID:
   - Remove `CU-` prefix if present
   - Remove `#` prefix if present
   - Extract ID from URL if full URL provided (match `clickup.com/t/<id>` pattern)
3. Parse optional `--context` flag

### 2. Retrieve Ticket Information

1. Use `mcp__clickup__getTaskById` to retrieve:
   - Title and description
   - Status and priority
   - Tags and custom fields
   - Comments and discussion history
   - Subtasks (if any)
2. If linked documents exist, use `mcp__clickup__readDocument` to retrieve their content
3. Use `mcp__clickup__getListInfo` to understand the project context

**If the MCP server is unavailable:** Inform the user that ticket retrieval failed and ask them to provide the ticket details manually, then continue the estimation with the provided information.

### 3. Gather Related Context

1. Use `mcp__clickup__searchTasks` to find similar completed tasks in the same list or project. Look for tasks with similar tags or keywords from the title. Limit to 5-10 results.
2. Note any comparable past tasks and their apparent scope (based on description length, subtask count, and comments volume) to calibrate the estimate.

### 4. Lightweight Codebase Assessment

**Only if a codebase is available in the current working directory:**

1. Detect repository type by checking for key files:
   - Backend: `composer.json`, `artisan`, `requirements.txt`, `pyproject.toml`, `go.mod`
   - Frontend: `package.json`, `src/components/`, `vite.config.*`, `next.config.*`
   - Fullstack: Both indicators present
2. If the ticket description mentions specific areas (modules, files, features), use `Glob` and `Grep` to check:
   - Whether those areas exist in the codebase
   - How many files are in the affected area
   - Whether there are existing patterns to follow or if new patterns need to be established
3. Check if a branch already exists for this ticket:
   ```bash
   git branch -a --list "*CU-<ticketId>*"
   ```

### 5. Analyze and Estimate

Consider all gathered information and evaluate:

**Complexity factors:**
- Scope breadth: How many areas of the codebase are affected?
- Technical depth: Does it require new patterns, integrations, or architectural changes?
- Requirements clarity: Are requirements well-defined or ambiguous?
- Dependencies: Does it depend on external systems, APIs, or other tickets?
- Testing effort: How much testing is needed (unit, integration, E2E)?
- Risk level: What could go wrong? Are there unknowns?

**Calibration:**
- If similar past tasks were found, use them as reference points
- If codebase patterns exist, factor in whether this follows or diverges from them
- If `--context` was provided, incorporate it into the assessment

### 6. Present Estimation

Structure the output as follows:

---

**Ticket:** `<ticket-title>` (`CU-<ticket-id>`)
**List:** `<list-name>`
**Priority:** `<priority>`

#### Summary

_2-3 sentence summary of what the ticket requires, written from a technical perspective._

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

_Bulleted list of factors that could affect the estimate. Each item should describe the risk and its potential impact on time. If none, state "No significant risks identified."_

#### Dependencies and Blockers

_Bulleted list of external dependencies, other tickets, or preconditions. If none, state "No dependencies identified."_

#### Recommendations

_Optional. 1-3 actionable suggestions that could reduce risk or effort (e.g., "Clarify the expected behavior for edge case X before starting", "Consider splitting into two tickets")._

---

## Complexity Scale Reference

| Level | Description | Typical Range |
|-------|-------------|---------------|
| **Simple** | Single area, clear requirements, follows existing patterns, minimal testing | 1h - 4h |
| **Medium** | Few areas, mostly clear requirements, some new logic, moderate testing | 4h - 12h |
| **Complex** | Multiple areas, some ambiguity, new patterns or integrations, significant testing | 12h - 30h |
| **Very Complex** | Cross-cutting concerns, architectural changes, high ambiguity, extensive testing | 30h+ |

These ranges are guidelines. Adjust based on codebase size, team context, and the `--context` flag.

## Notes

- This command is read-only. It does not modify any files or update the ticket.
- Estimates are rough assessments based on available information, not commitments.
- For a full implementation plan, use `/hxm:plan-ticket` instead.
- Additional context provided via `--context` is factored into the analysis.
