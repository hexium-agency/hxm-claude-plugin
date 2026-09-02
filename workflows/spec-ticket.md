---
name: spec-ticket
description: Extract a ticket's full specification and analyze gaps in the codebase
arguments: <ticket> [--feedback] [--context "additional context"]
trigger: Use when the user asks for the full specification of a ticket, or to check what a ticket really requires against the codebase. Extracts the requirements, checks the Figma design when one is referenced and lists the gaps.
requires: clickup, figma
---

# Ticket Specification and Gap Analysis

Analyzes a ticket from any supported ticket manager (ClickUp by default) and produces a read-only report: the ticket's full specification plus an analysis of what is missing in the codebase to cover every case and goal. It does **not** produce an ordered implementation plan — the goal is to give you everything you need to build your own checklist and iterate in small increments. For a turnkey implementation plan, use `{{command:plan-ticket}}` instead.

## Usage

```
{{command:spec-ticket}} <ticket> [--feedback] [--context "additional context"]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `ticket` | string | **Required.** Ticket URL or ID (e.g., `abc123`, `CU-abc123`, or full ClickUp URL) |
| `--feedback` | flag | Indicates the ticket has already been partially implemented and we are addressing client feedback |
| `--context` | string | Additional context to consider during analysis |

## Examples

```bash
# Analyze a ClickUp ticket by ID
{{command:spec-ticket}} abc123

# Analyze a ticket that has client feedback to address
{{command:spec-ticket}} abc123 --feedback

# Analyze with additional context
{{command:spec-ticket}} abc123 --context "This is related to the payment module refactoring"

# Analyze from a full URL with feedback mode
{{command:spec-ticket}} https://app.clickup.com/t/abc123 --feedback --context "Focus on the export flow"
```

## Process

### 1. Parse Arguments

1. Extract the ticket identifier from the first positional argument
2. Clean the ticket ID:
   - Remove `CU-` prefix if present
   - Remove `#` prefix if present
   - Extract ID from URL if full URL provided (match `clickup.com/t/<id>` pattern)
3. Determine the ticket manager from the URL format (default to ClickUp if no specific format is detected)
4. Parse optional flags:
   - `--feedback`: boolean, indicates we are addressing client feedback on an existing implementation
   - `--context`: additional context string (may be empty)

### 2. Detect Repository Type

Automatically detect the repository type by examining the codebase:

**Backend indicators:**
- `composer.json` with Laravel dependencies
- `artisan` file present
- `app/Http/Controllers` directory
- `routes/api.php` or `routes/web.php`
- Python: `requirements.txt`, `pyproject.toml`, Django/FastAPI patterns

**Frontend indicators:**
- `package.json` with React, Vue, Angular, or similar dependencies
- `src/components` or `src/pages` directories
- `vite.config.*`, `next.config.*`, `nuxt.config.*`
- `tailwind.config.*`, `postcss.config.*`

**Fullstack indicators:**
- Both backend and frontend patterns present
- Monorepo structure with separate packages

Store the detected type for scope-specific analysis later.

### 3. Retrieve Ticket Information

**For ClickUp tickets:**

1. Using the connected ClickUp MCP server, retrieve the full ticket by its ID — title, description, status,
   priority, and attachment metadata. Pick whichever tool the server exposes for fetching a task by ID. If
   comments are not included in that response, also call the server's tool for the task's comments and
   discussion history.
2. If attachments are referenced, note them for later inspection
3. If linked documents exist, retrieve their content via the server's document capability (list the
   document's pages, then fetch each page)

**CRITICAL:** If the MCP server is unavailable, inform the user that ticket retrieval failed and ask them to provide the ticket details manually, then continue with the provided information.

### 4. Build the Specification

This is the first core deliverable — share the complete specification. From the full corpus (description + comments chronologically + linked documents + attachments), extract exhaustively:

1. **Goal(s):** the "why" behind the ticket.
2. **Functional requirements:** the "what" the feature must do.
3. **All cases / scenarios to cover:** nominal path, edge cases, error states, permissions/roles, empty states, etc. This section must be the most thorough — it is the basis for the user's checklist.
4. **Technical constraints:** explicit technologies, patterns, or limitations.
5. **Acceptance criteria:** how to verify completion.
6. **Client-specific work rules:** identify and surface every client-specific instruction or convention present in the ticket or its comments (e.g., naming, imposed wording/labels, date/currency format, process constraints, "never do X", validation/QA requirements, particular code conventions). Give these a dedicated section — they are easy to miss and critical for compliance.
7. **Ambiguities / missing information:** list anything unclear in the ticket (do not ask interactive questions — this command is read-only).

**If `--feedback` flag is set:**
- Focus on the most recent comments containing client feedback
- Distinguish what was already implemented from what needs changes
- Separate bug fixes, requested modifications, and new requirements

### 5. Check Design / Figma References

If the ticket (description, comments, linked documents, attachments) references a design or a Figma link:

1. Retrieve the design via the Figma MCP tools (`get_design_context`, `get_screenshot`, `get_metadata`) on the referenced URL or node.
2. **Compare design against the ticket specification:** report inconsistencies — elements present in the design but absent from the ticket text and vice versa, states/screens not covered, diverging labels. These discrepancies feed both the "Ambiguities" and the cases to cover.
3. If no design is referenced, skip this step (note it as "no design provided"). If the Figma MCP is unavailable, report it and continue without the design check.

### 6. Explore the Codebase

<!-- provider:claude -->
1. Use the Task tool with `subagent_type=Explore` to, based on the detected repository type:
<!-- /provider -->
<!-- provider:codex -->
1. Explore the codebase yourself (targeted greps and reads), based on the detected repository type:
<!-- /provider -->
   - Find existing patterns related to each requirement
   - Locate the files and modules that handle (or should handle) each case
   - Determine the current state of the code for the affected area
2. Document findings relevant to the gap analysis with concrete file references (`path:line`).

**If `--feedback` flag is set:**
- Also identify the files that were modified in the initial implementation
- Look for existing tests that may need updates

### 7. Gap Analysis

This is the second core deliverable — what is missing in the code. For each case/requirement from step 4, compare against the code state from step 6 and classify it as **covered** / **partially covered** / **missing**. Reference the affected files (`path:line`). This is what lets the user build their own checklist.

**If `--feedback` flag is set:**
- Orient the gap analysis toward the requested deltas rather than the whole feature

### 8. Present Report

Output the report directly (no plan file, no plan mode), as structured markdown:

---

**Ticket:** `<title>` (`CU-<id>`)
**Status / Priority:** `<status>` / `<priority>`
**Repo type:** backend | frontend | fullstack

#### Goal

_1-3 sentences: the why behind the ticket._

#### Specification

- Functional requirements (list)
- Cases to cover (exhaustive: nominal, edge, error, permissions, empty states…)
- Technical constraints
- Acceptance criteria

#### ⚠️ Client-Specific Work Rules

_Surfaced list of every client-specific instruction or convention (naming, imposed wording, date/currency format, process, "never do X", QA…). State "No specific rules identified" otherwise._

#### Design Consistency (Figma)

_If a design is referenced: discrepancies design ↔ spec (design elements/states not described in the ticket and vice versa, diverging labels). Otherwise "No design provided"._

#### Gap Analysis (code vs spec)

| Case / Requirement | Code state | Gap to close | Affected files |
|--------------------|------------|--------------|----------------|
| ... | Covered / Partial / Missing | ... | `path:line` |

#### Ambiguities to Resolve

_Unclear points in the ticket plus any design inconsistencies found (no interactive question)._

---

**If `--feedback` flag is set:** add a "Feedback Summary" section listing each feedback item and marking which are fixes vs enhancements.

## Output

The command produces a read-only report containing:
1. A ticket summary showing retrieved information
2. The full specification, including client-specific work rules
3. A design consistency check when a Figma design is referenced
4. A gap analysis mapping each case to its current code state

## Notes

- Read-only: does not modify any file, does not update the ticket, and performs no Git action.
- Intentionally does **not** produce an ordered implementation plan or execution order — the user builds their own checklist from the gap analysis and iterates in small increments. See `{{command:plan-ticket}}` for a turnkey plan.
- Surfaces client-specific work rules and verifies design ↔ spec consistency whenever a Figma design is referenced.
- Falls back to manual ticket details if the ClickUp MCP is unavailable; if the Figma MCP is unavailable, it reports this and continues without the design check.
- Additional context provided via `--context` is incorporated into the analysis.
- The `--feedback` flag refocuses the analysis on client returns on existing work.
