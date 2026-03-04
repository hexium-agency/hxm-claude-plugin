---
description: Review the current branch — retrieves linked ClickUp ticket, analyzes all changes, and provides a comprehensive wrap-up report on the feature, code quality, and maintainability.
allowed-tools: [Read, Glob, Grep, Bash, Task, mcp__clickup__getTaskById, mcp__clickup__searchTasks, mcp__clickup__getListInfo, mcp__clickup__readDocument]
argument-hint: [ticket] [--base <branch>]
model: opus
---

# /hxm:wrap-up - Branch Wrap-Up Review

Reviews the current branch by retrieving the linked ClickUp ticket, analyzing all changes against the base branch, and producing a comprehensive report covering feature completeness, code quality, and maintainability.

## Usage

```bash
/hxm:wrap-up [ticket] [--base <branch>]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `ticket` | string | Optional. ClickUp ticket ID or URL. If omitted, extracted from the branch name (`CU-<id>` pattern). |
| `--base` | string | Optional. Base branch to compare against. Defaults to auto-detection (`main`, `master`, or `develop`). |

## Examples

```bash
# Auto-detect ticket from branch name, auto-detect base branch
/hxm:wrap-up

# Specify a ticket explicitly
/hxm:wrap-up abc123

# Specify a different base branch
/hxm:wrap-up --base develop
```

## Process

### 1. Identify Base Branch

1. If `--base` is provided, use it.
2. Otherwise, detect the default branch:
   - Run `git branch -l main master develop` and pick the first that exists.
   - If none exists, abort with an error asking the user to provide `--base`.

### 2. Identify Current Branch and Ticket

1. Run `git branch --show-current` to get the current branch name.
2. If the branch is the base branch itself, abort: "You are on the base branch. Switch to a feature branch first."
3. Determine the ClickUp ticket ID:
   - If `ticket` argument is provided, use it (clean `CU-` prefix, `#` prefix, or extract from URL).
   - Otherwise, attempt to extract from the branch name using the pattern `CU-([a-z0-9]+)` (case-insensitive).
   - If no ticket ID is found, continue without ticket context and note this in the report.

### 3. Retrieve Ticket Information

**Skip this step if no ticket ID was found.**

1. Use `mcp__clickup__getTaskById` to retrieve:
   - Title and description
   - Status and priority
   - Acceptance criteria (from description or custom fields)
   - Comments and discussion history
2. If linked documents exist, use `mcp__clickup__readDocument` to retrieve content.
3. Compile a ticket summary with:
   - What the feature is supposed to do (functional requirements)
   - Any technical constraints mentioned
   - Acceptance criteria or definition of done
4. If the MCP server is unavailable, note the failure and proceed without ticket context.

### 4. Gather Branch Changes

Run the following commands in parallel to collect all branch information:

```bash
git log <base>..HEAD --oneline                    # Commit history on this branch
git diff <base>..HEAD --stat                       # Files changed summary
git diff <base>..HEAD                              # Full diff of all changes
git diff <base>..HEAD --name-status                # List of added/modified/deleted files
```

If the diff is very large (more than 200 files changed), use the Task tool with `subagent_type=Explore` to analyze files in batches rather than reading the entire diff at once.

### 5. Analyze Changes

Review all changes with the following focus areas. Use `Read` to inspect specific files when the diff alone is insufficient to assess quality.

#### 5a. Feature Completeness

Compare the changes against the ticket requirements (if available):

- Which requirements appear to be implemented?
- Which requirements appear to be missing or incomplete?
- Are there changes that go beyond the ticket scope (scope creep)?
- Are there edge cases that seem unhandled?

If no ticket is linked, assess the feature based on commit messages and code intent.

#### 5b. Code Quality

Evaluate the code changes for:

- **Readability:** Clear naming, appropriate comments, self-documenting code
- **Consistency:** Follows existing codebase patterns and conventions
- **Error handling:** Proper error handling, edge cases covered
- **Duplication:** No unnecessary code duplication, DRY principle
- **Complexity:** No over-engineering, appropriate level of abstraction

#### 5c. Maintainability

Assess long-term health of the changes:

- **Test coverage:** Are new features covered by tests? Are tests meaningful?
- **Dependencies:** Any new dependencies introduced? Are they justified?
- **Architecture:** Do changes fit the existing architecture or introduce inconsistencies?
- **Technical debt:** Do changes introduce or reduce technical debt?
- **Documentation:** Are complex sections documented? Are public APIs documented?

#### 5d. Security and Performance

Flag any obvious concerns:

- Hardcoded secrets or credentials
- SQL injection, XSS, or other common vulnerabilities
- N+1 queries or other performance anti-patterns
- Missing input validation or sanitization
- Exposed sensitive data in responses

### 6. Produce Report

Present the wrap-up report in the following structure:

---

**Branch:** `<branch-name>` → `<base-branch>`
**Ticket:** `<ticket-title>` (`<ticket-id>`) — or "No linked ticket"
**Commits:** `<count>` commits | **Files changed:** `<count>`

#### Ticket Summary

_Brief summary of what the ticket requires (or "No ticket linked — review based on code changes only")._

#### Feature Completeness

- Status: **Complete** / **Mostly complete** / **Incomplete**
- Implemented: list of implemented requirements
- Missing or incomplete: list of gaps (if any)
- Out of scope: list of changes beyond ticket scope (if any)

#### Code Quality

- Rating: **Good** / **Acceptable** / **Needs improvement**
- Highlights: what is done well
- Issues: specific problems found, with file references

#### Maintainability

- Rating: **Good** / **Acceptable** / **Needs improvement**
- Test coverage: assessment of test adequacy
- Architecture fit: how well changes integrate
- Technical debt: introduced vs resolved

#### Concerns

_List any security, performance, or other concerns. "None identified" if clean._

#### Recommendations

_Numbered list of actionable suggestions before merging, ordered by priority._

---

## Notes

- This command is read-only. It does not modify any files, make commits, or update the ticket.
- The report is based on the diff against the base branch, not the working tree. Uncommitted changes are not included in the review.
- For large branches with many changes, the analysis may take longer as files are read individually.
