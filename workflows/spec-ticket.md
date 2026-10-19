---
name: spec-ticket
description: Extract a ticket's full specification and analyze gaps in the codebase
arguments: <ticket> [--feedback] [--context "additional context"]
trigger: Use when the user asks for the full specification of a ticket, or to check what a ticket really requires against the codebase. Extracts the requirements, checks the Figma design when one is referenced and lists the gaps.
requires: clickup, figma
---

# Ticket Specification and Gap Analysis

Analyzes a ticket from any supported ticket manager (ClickUp by default) and produces a read-only report: the full specification plus what is missing in the codebase to cover every case and goal. It does **not** produce an ordered implementation plan: the user builds their own checklist and iterates in small increments. For a turnkey plan, use `{{command:plan-ticket}}`.

## Usage

```
{{command:spec-ticket}} <ticket> [--feedback] [--context "additional context"]
```

| Argument | Type | Description |
|----------|------|-------------|
| `ticket` | string | **Required.** Ticket URL or ID (`abc123`, `CU-abc123`, full ClickUp URL) |
| `--feedback` | flag | Ticket already partially implemented; addressing client feedback |
| `--context` | string | Additional context to incorporate into the analysis |

```bash
{{command:spec-ticket}} abc123
{{command:spec-ticket}} https://app.clickup.com/t/abc123 --feedback --context "Focus on the export flow"
```

## Process

### 1. Parse Arguments

1. First positional argument is the ticket identifier; clean it: strip `CU-` and `#` prefixes, extract the ID from a URL (`clickup.com/t/<id>`).
2. Ticket manager: from the URL format, ClickUp by default.
3. Parse `--feedback` (boolean) and `--context` (string, may be empty). Free text after the ticket is an implicit `--context`, appended to any explicit one.
4. Images pasted in the invocation are part of the specification: analyze them with the ticket corpus.

### 2. Detect Repository Type

Store the detected type for later scope-specific analysis:

- **Backend:** `composer.json` with Laravel, `artisan`, `app/Http/Controllers`, `routes/api.php` or `routes/web.php`, Python (`requirements.txt`, `pyproject.toml`, Django/FastAPI patterns)
- **Frontend:** `package.json` with React/Vue/Angular or similar, `src/components` or `src/pages`, `vite.config.*`, `next.config.*`, `nuxt.config.*`, `tailwind.config.*`, `postcss.config.*`
- **Fullstack:** both present, or monorepo with separate packages

### 3. Retrieve Ticket Information

For ClickUp, with the connected MCP server:

1. Fetch the ticket by ID (title, description, status, priority, attachment metadata) with whichever task-fetch tool the server exposes. If comments are not included, also call its task-comments tool.
2. **Comment threads:** fetch the thread of every comment that has replies with the threaded-comments tool. If the URL carries `?comment=<id>`, fetch that thread first and treat it as the focus of the request. A decision in a comment or reply overrides the description.
3. **Attachments:** for every image or PDF, request a download link via the attachment download capability, fetch it immediately and only once into a scratch directory outside the repository, then read it. On failure, list the unreadable attachments and ask the user to paste them.
4. **Linked documents:** retrieve via the document capability (list pages, then fetch each page).

**CRITICAL:** If the MCP server is unavailable, tell the user retrieval failed, ask for the ticket details manually, then continue with them.

### 4. Build the Specification

First core deliverable: share the complete specification. Extract exhaustively from the full corpus (description + comments and threads chronologically + linked documents + attachments + pasted images). When a comment records a decision differing from the description, the comment wins: state the override.

1. **Goal(s):** the "why".
2. **Functional requirements:** the "what".
3. **All cases / scenarios:** nominal, edge, error states, permissions/roles, empty states, etc. The most thorough section: it is the basis of the user's checklist.
4. **Technical constraints:** explicit technologies, patterns, limitations.
5. **Acceptance criteria:** how to verify completion.
6. **Client-specific work rules:** every client-specific instruction or convention in the ticket or comments (naming, imposed wording/labels, date/currency format, process constraints, "never do X", validation/QA requirements, code conventions). Dedicated section: easy to miss, critical for compliance.
7. **Ambiguities / missing information:** list anything unclear; no interactive questions (read-only).

**`--feedback`:** focus on the most recent client-feedback comments; distinguish what is already implemented from what needs changes; separate bug fixes, requested modifications and new requirements.

### 5. Check Design / Figma References

If the ticket (description, comments, linked documents, attachments) references a design or Figma link:

1. Retrieve it via the Figma MCP tools (`get_design_context`, `get_screenshot`, `get_metadata`) on the referenced URL or node.
2. Compare design against specification and report inconsistencies: elements in the design but not the ticket text and vice versa, uncovered states/screens, diverging labels. They feed both "Ambiguities" and the cases to cover.
3. No design referenced: skip and note "no design provided". Figma MCP unavailable: report it and continue without the design check.

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
2. Document findings relevant to the gap analysis with concrete references (`path:line`).

**`--feedback`:** also identify files modified in the initial implementation and existing tests that may need updates.

### 7. Gap Analysis

Second core deliverable. Compare each case/requirement from step 4 against the code state from step 6 and classify it **covered** / **partially covered** / **missing**, with affected files (`path:line`). **`--feedback`:** orient the analysis toward the requested deltas rather than the whole feature.

### 8. Present Report

Output the report directly (no plan file, no plan mode) as structured markdown:

---

**Ticket:** `<title>` (`CU-<id>`)
**Status / Priority:** `<status>` / `<priority>`
**Repo type:** backend | frontend | fullstack

#### Goal

_1-3 sentences: the why._

#### Specification

- Functional requirements (list)
- Cases to cover (exhaustive: nominal, edge, error, permissions, empty states…)
- Technical constraints
- Acceptance criteria

#### ⚠️ Client-Specific Work Rules

_Every client-specific instruction or convention. "No specific rules identified" otherwise._

#### Design Consistency (Figma)

_If a design is referenced: discrepancies design ↔ spec. Otherwise "No design provided"._

#### Gap Analysis (code vs spec)

| Case / Requirement | Code state | Gap to close | Affected files |
|--------------------|------------|--------------|----------------|
| ... | Covered / Partial / Missing | ... | `path:line` |

#### Ambiguities to Resolve

_Unclear ticket points plus design inconsistencies (no interactive question)._

---

**`--feedback`:** add a "Feedback Summary" section listing each feedback item, marking fixes vs enhancements.

## Notes

- Read-only: modifies no file, does not update the ticket, performs no Git action.
- No ordered implementation plan or execution order: the user builds their checklist from the gap analysis. See `{{command:plan-ticket}}` for a turnkey plan.
- Falls back to manual ticket details if the ClickUp MCP is unavailable; if the Figma MCP is unavailable, reports it and continues without the design check.
- `--context` is incorporated into the analysis; `--feedback` refocuses it on client returns on existing work.
