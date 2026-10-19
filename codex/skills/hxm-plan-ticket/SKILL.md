---
name: hxm-plan-ticket
description: Use when the user asks to plan, prepare or scope a ticket before implementing it. Reads the ticket, explores the codebase, resolves ambiguities with the user and produces a step-by-step implementation plan. Coordinates with peer sessions planning other parts of the same ticket, the backend session leading.
---

# Ticket Analysis and Implementation Planning

Analyzes a ticket from any supported ticket manager (ClickUp by default), retrieves all relevant information, and prepares an implementation plan.

## Usage

```
$hxm-plan-ticket <ticket> [--feedback] [--context "additional context"] [--scope <role>] [--peer <session>[,<session>]]
```

| Argument | Type | Description |
|----------|------|-------------|
| `ticket` | string | **Required.** Ticket URL or ID (`abc123`, `CU-abc123`, or full ClickUp URL) |
| `--feedback` | flag | Ticket already partially implemented; addressing client feedback |
| `--context` | string | Additional context for the analysis |
| `--peer` | string | Comma-separated peer sessions planning other parts of the same ticket. Discovered automatically when omitted (step 9) |
| `--scope` | string | Part of the ticket this session plans (e.g., `backend`, `frontend`). Overrides the detected repository type |

```bash
$hxm-plan-ticket abc123
$hxm-plan-ticket https://app.clickup.com/t/abc123 --feedback --context "Focus on performance issues mentioned"
$hxm-plan-ticket abc123 --scope frontend --peer abc123-backend
```

## Process

Steps 1 to 3 gather the ticket and set up the branch. They run **before** plan mode, because plan mode forbids the
branch operations and the attachment downloads they need.

### 1. Parse Arguments

1. Extract the ticket identifier from the first positional argument. Manager: ClickUp if the URL contains
   `clickup.com` or the ID matches ClickUp patterns; default to ClickUp
2. Parse flags: `--feedback` (boolean), `--context`, `--scope`, `--peer` (list); the last three may be empty
3. Free text after the ticket is an implicit `--context`, appended to any explicit one. When it states the part
   this session plans or names another session (e.g., "you plan the backend, talk with `abc123-frontend`"), treat
   it as `--scope` and `--peer`
4. Images pasted in the invocation are part of the specification: analyze them with the ticket corpus
5. Write the plan and the questions in the language the user writes in

### 2. Retrieve Ticket Information

1. Clean the ID: strip `CU-` and `#` prefixes; extract it from a full URL
2. With the connected ClickUp MCP server, retrieve the full ticket by ID (title, description, status, priority,
   attachment metadata) using whichever task-fetch tool it exposes. If comments are not included, also call its
   task comments tool
3. **Comment threads:** fetch the thread of every comment with replies using the threaded-comments tool. When the
   URL carries `?comment=<id>`, fetch that thread first and treat it as the focus of the request. A decision made
   in a comment or reply overrides the description
4. **Attachments:** for every image or PDF, request a download link with the server's attachment download
   capability, fetch it immediately and only once into a scratch directory outside the repository, then read it.
   If a download fails, list the unreadable attachments and ask the user to paste them
5. Retrieve linked documents via the server's document capability (may require listing the pages, then fetching
   each)

**CRITICAL:** If the MCP server is unavailable, tell the user ticket retrieval failed and ask for the ticket details manually.

### 3. Check Git Branch

1. Get the current branch with `git branch --show-current`
2. Prefix: `fix/` for bug/fix tickets, `feat/` for feature/enhancement tickets
3. Suggested name: `{prefix}CU-{ticketId}-{summary}`. **CRITICAL:** the summary MUST be English (translate if
   needed), a concise description of what the ticket actually requires (not the possibly unclear client-written
   title), kebab-case, lowercase, max 50 characters. E.g., `feat/CU-abc123-add-user-export-csv`, not
   `feat/CU-abc123-export-problem`
4. **On `main`, `master`, `develop`, or `staging`** (never renamed):
   - Ask the user about branch creation and wait for the answer:
     - Create the suggested name / enter a custom name / stay on the current branch (not recommended)
   - If accepted, **execute immediately** `git checkout -b <branch-name>`
5. **On another branch**, extract any ticket ID from its name, case-insensitively (e.g., `CU-abc123`, or
   `cu-abc123` in `fix/cu-abc123-account-invoice`):
   - **Same ticket ID:** keep the branch silently. Never ask about renaming, whatever the case or the rest of the name
   - **Different ticket ID:**
     - Ask the user for context and wait for the answer:
       - Multiple tickets in this branch? / Mistake, should we switch branches? / Continue anyway?
     - If the user wants to switch, **execute immediately**
   - **No ticket ID:**
     - Ask the user about renaming and wait for the answer:
       - Rename to the suggested name / keep the current name / enter a custom name
     - If accepted, **execute immediately** `git branch -m <new-name>`

**CRITICAL:** Execute branch operations immediately after user confirmation, before entering plan mode and before any other analysis or questions. Never defer them to the implementation plan.

### 4. Enter Planning Mode

**CRITICAL:** From now on, treat this workflow as read-only planning. Do not modify a file, run a write command, or start implementing until the plan has been explicitly approved by the user. When the ticket already raises many open questions, a clarification round (rules of step 10) may happen first.

### 5. Detect Repository Type

Detect from the codebase:

- **Backend:** `composer.json` with Laravel dependencies, `artisan`, `app/Http/Controllers`, `routes/api.php` or
  `routes/web.php`; Python: `requirements.txt`, `pyproject.toml`, Django/FastAPI patterns
- **Frontend:** `package.json` with React, Vue, Angular or similar, `src/components` or `src/pages`,
  `vite.config.*`, `next.config.*`, `nuxt.config.*`, `tailwind.config.*`, `postcss.config.*`
- **Fullstack:** both patterns present, or a monorepo with separate packages

Store the type for step 7. `--scope`, when set, replaces the detected type.

### 6. Analyze Ticket Corpus

1. Compile: ticket description, all comments with threaded replies (chronological), linked documents, downloaded
   attachments and pasted images
2. When a comment or reply records a decision that differs from the description, the comment wins; state the
   override in the plan
3. Identify functional requirements, technical constraints (technologies, patterns, limitations) and acceptance
   criteria
4. Note ambiguities and missing information

**With `--feedback`:**
- Focus on the most recent comments containing client feedback
- Identify what is already implemented vs what needs changes
- Distinguish bug fixes, requested modifications and new requirements
- Prioritize feedback items by severity and impact

### 7. Scope-Specific Analysis

By repository type:

- **Backend:** API endpoints, database changes, services, business logic; affected files and modules; data models, migrations, validation rules
- **Frontend:** UI components, state management, user interactions; affected views, components, assets; UX flow, accessibility, responsive design
- **Fullstack:** both sides; cross-cutting concerns (authentication, logging, caching); integration points

### 8. Explore Codebase

1. Explore the codebase yourself (targeted greps and reads) to:
   - Find existing patterns related to the requirements
   - Identify files and modules to modify
   - Understand the current architecture of the affected area
2. Document the findings relevant to the implementation

**With `--feedback`:** also identify files modified in the initial implementation and existing tests that may need updates.

### 9. Coordinate with Peer Sessions

Skip when no peer session is involved.

1. **Find the peers:**
   - Use the sessions given by `--peer`. Codex cannot discover or message other sessions, so skip this step when
     `--peer` is empty
   - Infer each peer's role from its name suffix: `backend`, `back`, `api`, `server` → backend; `frontend`,
     `front`, `app`, `client` → frontend
2. **Lead:** the session whose scope is backend. If no participant has a backend scope, ask the user once which session leads
3. **Lead:**
   - Send each peer the scope split and a draft contract (endpoints, payloads, fields, events)
   - Own every question concerning more than one scope: collect the peers' cross-cutting questions, ask the user
     once, relay the answers
   - Keep the agreed contract as the source of truth; notify the peers of any change, including when the ticket is updated during planning
4. **Peers:**
   - Send the lead this scope's needs and review the draft contract
   - Never ask the user a cross-cutting question; forward it to the lead
   - Ask the user directly only about decisions confined to this scope
5. Wait for the peers to agree on the contract before preparing the plan. If a peer does not answer, continue and
   mark the contract as not confirmed by that peer in the plan

Write each message intended for a peer as a copy-paste-ready block and ask the user to relay it, then wait for the
user to paste the answer.

### 10. Ask Clarifying Questions

If ambiguities or missing information were identified:

1. Ask the user directly to gather clarification
2. One decision per question, specific and actionable
3. Put shared facts in a short preamble; keep each question's description to two lines or less
4. Offer reasonable default options when possible, with a recommended one

With peers, only the lead asks cross-cutting questions (step 9).

**CRITICAL:** Do not proceed to planning if critical information is missing. Gather all clarifications first.

### 11. Prepare Implementation Plan

Include:

1. **Ticket Summary:** title, URL, key requirements
2. **Overview:** brief summary of the ticket and its goals
3. **Technical Approach:** high-level strategy
4. **Files to Modify/Create:** affected files with brief descriptions
5. **Implementation Steps:** ordered tasks with dependencies
6. **Testing Strategy:** how the implementation will be verified
7. **Verification Prerequisites:** everything verification needs, listed so the user approves it with the plan:
   - The stack to start, detached so it survives the session (e.g., `sail up -d`, not `sail up`)
   - The test accounts and data to seed, and how (seeder, factory, tinker command)
   - The local HTTP calls to run (URL and method), which need approval
8. **Risks and Considerations:** potential issues and mitigations

**With `--feedback`:** add a "Feedback Summary" section listing each feedback item, marking fixes vs enhancements, referencing the original implementation where relevant.

**With peers:**
- Add an "Agreed Contract" section, identical in every peer's plan, stating which peers confirmed it
- Add an "Out of Scope" section listing what each peer handles
- A plan concluding that this scope has nothing to implement is valid

### 12. Propose Plan

1. Write the plan to the plan file
2. Present the plan to the user and wait for explicit approval before any implementation
3. End with a **Next steps** line: verify the implementation, then `$hxm-commit-atomic` (with `--push` or
   `--pr`) or `$hxm-create-pr`. Propose these commands; never run them

## Output

1. A ticket summary of the retrieved information
2. Clarifying questions (if needed)
3. A structured implementation plan ready for approval, including its verification prerequisites
4. A closing "Next steps" line proposing verification, commit and pull request commands

## Notes

- Tickets are read-only; modifications require explicit user request
- The backend session leads by default when peers are involved

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
