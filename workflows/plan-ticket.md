---
name: plan-ticket
description: Analyze a ticket and prepare an implementation plan
arguments: <ticket> [--feedback] [--context "additional context"] [--scope <role>] [--peer <session>[,<session>]]
trigger: Use when the user asks to plan, prepare or scope a ticket before implementing it. Reads the ticket, explores the codebase, resolves ambiguities with the user and produces a step-by-step implementation plan. Coordinates with peer sessions planning other parts of the same ticket, the backend session leading.
requires: clickup
---

# Ticket Analysis and Implementation Planning

Analyzes a ticket from any supported ticket manager (ClickUp by default), retrieves all relevant information, and prepares an implementation plan.

## Usage

```
{{command:plan-ticket}} <ticket> [--feedback] [--context "additional context"] [--scope <role>] [--peer <session>[,<session>]]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `ticket` | string | **Required.** Ticket URL or ID (e.g., `abc123`, `CU-abc123`, or full ClickUp URL) |
| `--feedback` | flag | Indicates the ticket has already been partially implemented and we are addressing client feedback |
| `--context` | string | Additional context to consider during analysis |
| `--peer` | string | Comma-separated names of peer sessions planning other parts of the same ticket. Discovered automatically when omitted (see step 9) |
| `--scope` | string | The part of the ticket this session plans (e.g., `backend`, `frontend`). Overrides the detected repository type |

## Examples

```bash
# Analyze a ClickUp ticket by ID
{{command:plan-ticket}} abc123

# Analyze a ticket that has client feedback to address
{{command:plan-ticket}} abc123 --feedback

# Analyze with additional context
{{command:plan-ticket}} abc123 --context "This is related to the payment module refactoring"

# Analyze from full URL with feedback mode
{{command:plan-ticket}} https://app.clickup.com/t/abc123 --feedback --context "Focus on performance issues mentioned"

# Plan the frontend part while another session plans the backend
{{command:plan-ticket}} abc123 --scope frontend --peer abc123-backend
```

## Process

Steps 1 to 3 gather the ticket and set up the branch. They run **before** plan mode, because plan mode forbids the
branch operations and the attachment downloads they need.

### 1. Parse Arguments

1. Extract the ticket identifier from the first positional argument
2. Determine the ticket manager from the URL format:
   - ClickUp: URLs containing `clickup.com` or IDs matching ClickUp patterns
   - Default to ClickUp if no specific format is detected
3. Parse optional flags:
   - `--feedback`: boolean, indicates we are addressing client feedback on existing implementation
   - `--context`: additional context string (may be empty)
   - `--scope`: the role this session plans (may be empty)
   - `--peer`: list of peer session names (may be empty)
4. Free text after the ticket is an implicit `--context`, appended to any explicit one. When it states the part
   this session plans or names another session (e.g., "you plan the backend, talk with `abc123-frontend`"), treat
   it as `--scope` and `--peer`
5. Images pasted in the invocation are part of the specification: analyze them with the ticket corpus
6. Write the plan and the questions in the language the user writes in

### 2. Retrieve Ticket Information

**For ClickUp tickets:**

1. Clean the ticket ID:
   - Remove `CU-` prefix if present
   - Remove `#` prefix if present
   - Extract ID from URL if full URL provided
2. Using the connected ClickUp MCP server, retrieve the full ticket by its ID — title, description, status,
   priority, and attachment metadata. Pick whichever tool the server exposes for fetching a task by ID. If
   comments are not included in that response, also call the server's tool for the task's comments and
   discussion history.
3. **Comment threads:** for every comment that has replies, fetch its thread with the server's threaded-comments
   tool. When the URL carries `?comment=<id>`, fetch that thread first and treat it as the focus of the request.
   A decision made in a comment or a reply overrides the description
4. **Attachments:** for every image or PDF attachment, request a download link with the server's attachment
   download capability, fetch it immediately and only once into a scratch directory outside the repository, then
   read the file. If a download fails, list the attachments that could not be read and ask the user to paste them
5. If linked documents exist, retrieve their content via the server's document capability (this may require
   first listing the document's pages, then fetching each page)

**CRITICAL:** If the MCP server is unavailable, inform the user that ticket retrieval failed and ask them to provide the ticket details manually.

### 3. Check Git Branch

1. Get the current branch name using `git branch --show-current`

2. Determine branch prefix based on ticket type:
   - Bug/fix tickets → `fix/`
   - Feature/enhancement tickets → `feat/`

3. Generate suggested branch name: `{prefix}CU-{ticketId}-{summary}`
   - **CRITICAL:** The summary MUST be:
     - In English (translate if ticket is in another language)
     - A concise description of what the ticket actually requires (not just the ticket title, which may be unclear or poorly named by the client)
     - Kebab-case, lowercase, max 50 characters
     - Example: `feat/CU-abc123-add-user-export-csv` instead of `feat/CU-abc123-export-problem`

4. **If on `main`, `master`, `develop`, or `staging`:** these branches are never renamed.
   <!-- provider:claude -->
   - Use `AskUserQuestion` to ask about branch creation:
   <!-- /provider -->
   <!-- provider:codex -->
   - Ask the user about branch creation and wait for the answer:
   <!-- /provider -->
     - Option to create the suggested branch name
     - Option to enter a custom branch name
     - Option to stay on current branch (not recommended)
   - **Execute immediately** using `git checkout -b <branch-name>` if user accepts

5. **If on another branch**, extract any ticket ID from the branch name, case-insensitively (e.g., `CU-abc123`, or
   `cu-abc123` in a worktree branch such as `fix/cu-abc123-account-invoice`):

   - **If branch contains the same ticket ID:** keep it silently. Do not ask about renaming, whatever the case or
     the rest of the name

   - **If branch contains a different ticket ID than the one being analyzed:**
     <!-- provider:claude -->
     - Use `AskUserQuestion` to ask the user for context:
     <!-- /provider -->
     <!-- provider:codex -->
     - Ask the user for context and wait for the answer:
     <!-- /provider -->
       - Are we working on multiple tickets in this branch?
       - Is this a mistake and should we switch branches?
       - Should we continue anyway?
     - **Execute immediately** if user wants to switch branches

   - **If branch contains no ticket ID:**
     <!-- provider:claude -->
     - Use `AskUserQuestion` to ask about renaming:
     <!-- /provider -->
     <!-- provider:codex -->
     - Ask the user about renaming and wait for the answer:
     <!-- /provider -->
       - Option to rename to the suggested name
       - Option to keep current branch name
       - Option to enter a custom branch name
     - **Execute immediately** using `git branch -m <new-name>` if user accepts

**CRITICAL:** Branch operations MUST be executed immediately after user confirmation, before entering plan mode and before any other analysis or questions. Do not defer them to the implementation plan.

<!-- provider:claude -->
### 4. Enter Plan Mode

**CRITICAL:** If not already in plan mode, use `EnterPlanMode` now. All subsequent work happens within plan mode.
When the ticket already raises many open questions, a clarification round (following the rules of step 10) may
happen before entering plan mode.

<!-- /provider -->
<!-- provider:codex -->
### 4. Enter Planning Mode

**CRITICAL:** From now on, treat this workflow as read-only planning. Do not modify a file, run a write command, or start implementing until the plan has been explicitly approved by the user. When the ticket already raises many open questions, a clarification round (following the rules of step 10) may happen first.

<!-- /provider -->
### 5. Detect Repository Type

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

Store the detected type for scope-specific analysis later. When `--scope` is set, it replaces the detected type.

### 6. Analyze Ticket Corpus

1. Compile all retrieved information:
   - Main ticket description
   - All comments and their threaded replies (chronologically)
   - Linked document content
   - Downloaded attachments and images pasted in the invocation
2. When a comment or a reply records a decision that differs from the description, the comment wins. State the
   override in the plan
3. Identify key requirements:
   - Functional requirements (what the feature should do)
   - Technical constraints (specific technologies, patterns, or limitations)
   - Acceptance criteria (how to verify completion)
4. Note any ambiguities or missing information

**If `--feedback` flag is set:**
- Focus on the most recent comments containing client feedback
- Identify what was already implemented vs what needs changes
- Distinguish between bug fixes, requested modifications, and new requirements
- Prioritize feedback items by severity and impact

### 7. Scope-Specific Analysis

Based on the auto-detected repository type:

**For backend repositories:**
- Focus on API endpoints, database changes, services, business logic
- Identify affected backend files and modules
- Consider data models, migrations, validation rules

**For frontend repositories:**
- Focus on UI components, state management, user interactions
- Identify affected views, components, and assets
- Consider UX flow, accessibility, responsive design

**For fullstack repositories:**
- Analyze both backend and frontend implications
- Identify cross-cutting concerns (authentication, logging, caching)
- Consider full-stack integration points

### 8. Explore Codebase

<!-- provider:claude -->
1. Use the Task tool with `subagent_type=Explore` to:
<!-- /provider -->
<!-- provider:codex -->
1. Explore the codebase yourself (targeted greps and reads) to:
<!-- /provider -->
   - Find existing patterns related to the ticket requirements
   - Identify files and modules that will need modifications
   - Understand current architecture for the affected area
2. Document findings relevant to the implementation

**If `--feedback` flag is set:**
- Also identify files that were modified in the initial implementation
- Look for existing tests that may need updates

### 9. Coordinate with Peer Sessions

Skip this step when no peer session is involved.

1. **Find the peers:**
   <!-- provider:claude -->
   - Use the sessions given by `--peer`. When it is empty, call `ListAgents` and keep the sessions whose name
     starts with the ticket ID (case-insensitive), excluding this session
   <!-- /provider -->
   <!-- provider:codex -->
   - Use the sessions given by `--peer`. Codex cannot discover or message other sessions, so skip this step when
     `--peer` is empty
   <!-- /provider -->
   - Infer each peer's role from its name suffix: `backend`, `back`, `api`, `server` → backend; `frontend`,
     `front`, `app`, `client` → frontend
2. **Determine the lead:** the session whose scope is backend leads. If no participant has a backend scope, ask
   the user once which session leads
3. **Lead responsibilities:**
   - Send each peer the scope split and a draft contract (endpoints, payloads, fields, events)
   - Own every question that concerns more than one scope: collect the peers' cross-cutting questions, ask the user
     once, and relay the answers to the peers
   - Keep the agreed contract as the source of truth and notify the peers of any change, including when the
     ticket is updated during planning
4. **Peer responsibilities:**
   - Send the lead the needs of this scope and review the draft contract
   - Never ask the user a cross-cutting question; forward it to the lead instead
   - Ask the user directly only about decisions confined to this scope
5. Wait for the peers to agree on the contract before preparing the plan. If a peer does not answer, continue and
   mark the contract as not confirmed by that peer in the plan

<!-- provider:claude -->
Use `SendMessage` for every exchange with a peer.

<!-- /provider -->
<!-- provider:codex -->
Write each message intended for a peer as a copy-paste-ready block and ask the user to relay it, then wait for the
user to paste the answer.

<!-- /provider -->
### 10. Ask Clarifying Questions

If ambiguities or missing information were identified:

<!-- provider:claude -->
1. Use `AskUserQuestion` to gather clarification
<!-- /provider -->
<!-- provider:codex -->
1. Ask the user directly to gather clarification
<!-- /provider -->
2. Ask one decision per question, specific and actionable
3. Put the shared facts in a short preamble before the questions; keep each question's description to two lines
   or less
4. Offer reasonable default options when possible, with a recommended one

When coordinating with peers, only the lead asks cross-cutting questions (see step 9).

**CRITICAL:** Do not proceed to planning if critical information is missing. Gather all necessary clarifications first.

### 11. Prepare Implementation Plan

Create a comprehensive implementation plan that includes:

1. **Ticket Summary:** Title, URL, and key requirements extracted from the ticket
2. **Overview:** Brief summary of the ticket and its goals
3. **Technical Approach:** High-level strategy for implementation
4. **Files to Modify/Create:** List of affected files with brief descriptions
5. **Implementation Steps:** Ordered list of tasks with dependencies
6. **Testing Strategy:** How the implementation will be verified
7. **Verification Prerequisites:** Everything the verification needs, listed so the user approves it with the plan:
   - The stack to start, detached so it survives the session (e.g., `sail up -d`, not `sail up`)
   - The test accounts and data to seed, and how (seeder, factory, tinker command)
   - The local HTTP calls to run (URL and method), which need approval
8. **Risks and Considerations:** Potential issues and mitigation strategies

**If `--feedback` flag is set:**
- Include a "Feedback Summary" section listing each feedback item
- Mark which items are fixes vs enhancements
- Reference original implementation where relevant

**When coordinating with peers:**
- Include an "Agreed Contract" section, identical in every peer's plan, stating which peers confirmed it
- Include an "Out of Scope" section listing what each peer handles
- A plan concluding that this scope has nothing to implement is valid

### 12. Propose Plan

1. Write the implementation plan to the plan file
<!-- provider:claude -->
2. Use `ExitPlanMode` to present the plan for user approval
<!-- /provider -->
<!-- provider:codex -->
2. Present the plan to the user and wait for explicit approval before any implementation
<!-- /provider -->
3. End with a **Next steps** line: verify the implementation, then `{{command:commit-atomic}}` (with `--push` or
   `--pr`) or `{{command:create-pr}}`. Propose these commands; never run them

## Output

The command produces:
1. A ticket summary showing retrieved information
2. Clarifying questions (if needed)
3. A structured implementation plan ready for approval, including its verification prerequisites
4. A closing "Next steps" line proposing verification, commit and pull request commands

## Notes

- Tickets are read-only; modifications require explicit user request
- If MCP is unavailable, the command will ask for manual ticket details
- Additional context provided via `--context` or as free text after the ticket is incorporated into the analysis
- Comment threads and attachments are part of the ticket corpus; a decision made in a comment overrides the
  description
- A branch that already carries the ticket ID, in any case, is kept as is
- The `--feedback` flag changes the analysis focus to address client returns on existing work
- With peer sessions, the backend session leads by default and is the only one asking the user cross-cutting
  questions
