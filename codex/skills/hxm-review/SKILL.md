---
name: hxm-review
description: Use when the user asks for a code review of staged changes, of a specific file, or of a diff against a base branch. Reports findings by severity without modifying the code.
---

# Quick Code Review

Performs a focused code review on staged changes, a specific file, or a diff against a base branch. Unlike `$hxm-wrap-up` which provides a full branch report, this command delivers a fast, targeted review.

## Usage

```bash
$hxm-review [<target>] [--staged] [--base <branch>]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `target` | string | Optional. File path or directory to review. If omitted, reviews staged changes. |
| `--staged` | flag | Review only staged changes (default when no target is provided) |
| `--base` | string | Base branch for comparison (default: auto-detect main/master/develop) |

## Examples

```bash
# Review staged changes
$hxm-review --staged

# Review a specific file
$hxm-review src/services/auth.ts

# Review changes against develop
$hxm-review --base develop

# Review a directory
$hxm-review src/auth/
```

## Process

### 1. Determine Review Scope

- If `target` is a file path: Review that file (read current content + diff if modified)
- If `target` is a directory: Review all modified files in that directory
- If `--staged`: Review staged changes only (`git diff --cached`)
- If `--base`: Review diff against the specified branch (`git diff <base>..HEAD`)
- If no arguments: Default to `--staged`

### 2. Gather Changes

```bash
# For staged changes
git diff --cached

# For base branch comparison
git diff <base>..HEAD -- <target>

# For specific file/directory
git diff -- <target>
```

If no changes are found, read the target file(s) and review the current state.

### 3. Review Focus Areas

Evaluate the code for:

- **Bugs**: Logic errors, off-by-one, null/undefined handling, race conditions
- **Security**: Injection risks, hardcoded secrets, missing validation, exposed data
- **Performance**: N+1 queries, unnecessary loops, missing indexes, large payloads
- **Readability**: Unclear naming, missing context, overly complex logic
- **Patterns**: Consistency with codebase conventions, DRY violations, proper error handling

### 4. Present Review

Structure the review as:

**Scope:** what was reviewed (files, line count)

**Issues** (grouped by severity):
- **Critical**: Must fix before merge (bugs, security)
- **Warning**: Should fix (performance, patterns)
- **Suggestion**: Nice to have (readability, style)

Each issue includes:
- File and line reference
- Description of the problem
- Suggested fix (code snippet when helpful)

**Summary**: One-line verdict (Approved / Approved with suggestions / Changes requested)

## Notes

- This is a read-only command. It does not modify any files.
- For a comprehensive branch-level review with ticket context, use `$hxm-wrap-up` instead.
- Reviews focus on the diff, not the entire file, unless reviewing a file without changes.

## Guardrails

These rules override anything above them and are not negotiable:

- **Never commit, push, or tag without an explicit confirmation from the user in the current
  conversation.** Proposing a message is fine; running the command is not.
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
