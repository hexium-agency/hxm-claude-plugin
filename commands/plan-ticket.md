---
description: Analyze a ticket and prepare an implementation plan
allowed-tools: [Read, Glob, Grep, Bash, Task, AskUserQuestion, EnterPlanMode, ExitPlanMode, mcp__clickup__getTaskById, mcp__clickup__searchTasks, mcp__clickup__getListInfo, mcp__clickup__readDocument, WebFetch]
argument-hint: <ticket> [--feedback] [--context "additional context"]
model: opus
---

# /hxm:plan-ticket - Ticket Analysis and Implementation Planning

Analyzes a ticket from any supported ticket manager (ClickUp by default), retrieves all relevant information, and prepares an implementation plan.

## Usage

```
/hxm:plan-ticket <ticket> [--feedback] [--context "additional context"]
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
/hxm:plan-ticket abc123

# Analyze a ticket that has client feedback to address
/hxm:plan-ticket abc123 --feedback

# Analyze with additional context
/hxm:plan-ticket abc123 --context "This is related to the payment module refactoring"

# Analyze from full URL with feedback mode
/hxm:plan-ticket https://app.clickup.com/t/abc123 --feedback --context "Focus on performance issues mentioned"
```

## Process

### 1. Enter Plan Mode

**CRITICAL:** If not already in plan mode, immediately use `EnterPlanMode` to transition. All subsequent work happens within plan mode.

### 2. Parse Arguments

1. Extract the ticket identifier from the first positional argument
2. Determine the ticket manager from the URL format:
   - ClickUp: URLs containing `clickup.com` or IDs matching ClickUp patterns
   - Default to ClickUp if no specific format is detected
3. Parse optional flags:
   - `--feedback`: boolean, indicates we are addressing client feedback on existing implementation
   - `--context`: additional context string (may be empty)

### 3. Detect Repository Type

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

### 4. Retrieve Ticket Information

**For ClickUp tickets:**

1. Clean the ticket ID:
   - Remove `CU-` prefix if present
   - Remove `#` prefix if present
   - Extract ID from URL if full URL provided
2. Use `mcp__clickup__getTaskById` to retrieve the full ticket with:
   - Title and description
   - Status and priority
   - Comments and discussion history
   - Attachments metadata
3. If attachments are referenced, note them for later retrieval
4. If linked documents exist, use `mcp__clickup__readDocument` to retrieve their content

**CRITICAL:** If the MCP server is unavailable, inform the user that ticket retrieval failed and ask them to provide the ticket details manually.

### 5. Check Git Branch

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

4. **If on `main`, `master`, or `develop`:**
   - Use `AskUserQuestion` to ask about branch creation:
     - Option to create the suggested branch name
     - Option to enter a custom branch name
     - Option to stay on current branch (not recommended)
   - **Execute immediately** using `git checkout -b <branch-name>` if user accepts

5. **If on another branch**, extract any ticket ID from the branch name (e.g., `CU-abc123` pattern):

   - **If branch contains a different ticket ID than the one being analyzed:**
     - Use `AskUserQuestion` to ask the user for context:
       - Are we working on multiple tickets in this branch?
       - Is this a mistake and should we switch branches?
       - Should we continue anyway?
     - **Execute immediately** if user wants to switch branches

   - **If branch does not follow the convention or contains the same/no ticket ID:**
     - Use `AskUserQuestion` to ask about renaming:
       - Option to rename to the suggested name
       - Option to keep current branch name
       - Option to enter a custom branch name
     - **Execute immediately** using `git branch -m <new-name>` if user accepts

**CRITICAL:** Branch operations MUST be executed immediately after user confirmation, before proceeding to any other analysis or questions. Do not defer to the implementation plan.

### 6. Analyze Ticket Corpus

1. Compile all retrieved information:
   - Main ticket description
   - All comments (chronologically)
   - Linked document content
   - Attachment descriptions
2. Identify key requirements:
   - Functional requirements (what the feature should do)
   - Technical constraints (specific technologies, patterns, or limitations)
   - Acceptance criteria (how to verify completion)
3. Note any ambiguities or missing information

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

1. Use the Task tool with `subagent_type=Explore` to:
   - Find existing patterns related to the ticket requirements
   - Identify files and modules that will need modifications
   - Understand current architecture for the affected area
2. Document findings relevant to the implementation

**If `--feedback` flag is set:**
- Also identify files that were modified in the initial implementation
- Look for existing tests that may need updates

### 9. Ask Clarifying Questions

If ambiguities or missing information were identified:

1. Use `AskUserQuestion` to gather clarification
2. Questions should be specific and actionable
3. Provide context for why the question is important
4. Offer reasonable default options when possible

**CRITICAL:** Do not proceed to planning if critical information is missing. Gather all necessary clarifications first.

### 10. Prepare Implementation Plan

Create a comprehensive implementation plan that includes:

1. **Ticket Summary:** Title, URL, and key requirements extracted from the ticket
2. **Overview:** Brief summary of the ticket and its goals
3. **Technical Approach:** High-level strategy for implementation
4. **Files to Modify/Create:** List of affected files with brief descriptions
5. **Implementation Steps:** Ordered list of tasks with dependencies
6. **Testing Strategy:** How the implementation will be verified
7. **Risks and Considerations:** Potential issues and mitigation strategies

**If `--feedback` flag is set:**
- Include a "Feedback Summary" section listing each feedback item
- Mark which items are fixes vs enhancements
- Reference original implementation where relevant

### 11. Propose Plan

1. Write the implementation plan to the plan file
2. Use `ExitPlanMode` to present the plan for user approval

## Output

The command produces:
1. A ticket summary showing retrieved information
2. Clarifying questions (if needed)
3. A structured implementation plan ready for approval

## Notes

- Tickets are read-only; modifications require explicit user request
- If MCP is unavailable, the command will ask for manual ticket details
- Additional context provided via `--context` is incorporated into the analysis
- The `--feedback` flag changes the analysis focus to address client returns on existing work