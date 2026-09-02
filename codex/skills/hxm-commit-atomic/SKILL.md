---
name: hxm-commit-atomic
description: Use when the user asks to split pending work into several atomic commits, or to commit a large working tree mixing unrelated changes. Groups changes by logical unit and creates one conventional commit per group after explicit confirmation.
---

# Smart Atomic Commit Tool

CRITICAL: Follow the Process section exactly - this tool analyzes ALL changes (staged and unstaged), groups them
logically, and creates multiple atomic commits. Each commit follows conventional commit standards.

## Usage

```bash
$hxm-commit-atomic [--dry-run]
```

## Arguments

- No arguments: Analyze, group, and commit all changes
- `--dry-run`: Show proposed commit groups without executing commits

## Process

### 1. Gather All Changes

Run the following commands to get a complete picture:

```bash
git status --porcelain                    # All changed files
git diff                                  # Unstaged changes content
git diff --cached                         # Staged changes content
```

If no changes exist, exit with: "No changes to commit."

### 2. Analyze and Group Changes

Examine all modified files and their content to identify logical groupings. Consider:

- **Feature scope**: Files that implement the same feature belong together
- **Functional area**: Files in the same module/component (e.g., auth, api, ui)
- **Change type**: Separate refactors from features from fixes
- **Dependencies**: If file A depends on changes in file B, group them

Grouping rules:

1. Related source files + their tests = one commit
2. Configuration changes that enable a feature = same commit as the feature
3. Pure refactors = separate commit from feature changes
4. Documentation updates = separate commit unless directly tied to code changes
5. Style/formatting changes = separate commit

### 3. Determine Commit Order

Order commits logically:

1. Infrastructure/config changes first
2. Refactors that prepare for new code
3. Core feature implementations
4. Tests for new features
5. Documentation updates
6. Style/formatting fixes last

### 4. Present Commit Plan

Display the proposed commits in order:

```
Proposed atomic commits:

1. chore(config): add eslint rule for imports
   Files: .eslintrc.js

2. refactor(auth): extract token validation logic
   Files: src/auth/validator.ts, src/auth/validator.test.ts

3. feat(auth): add OAuth2 support
   Files: src/auth/oauth.ts, src/auth/oauth.test.ts, src/config/oauth.ts
```

### 5. Handle Dry Run or Confirmation

- If `--dry-run`: Display the plan and exit
- Otherwise: Ask the user to confirm in plain text, and wait for the answer before committing anything:
  - "Proceed with X commits?" — options: "Yes, execute all" / "Let me review first"
  - If user wants to review: Allow modifications to the plan

### 6. Execute Commits Sequentially

For each commit group:

1. Reset staging area: `git reset HEAD` (only if needed)
2. Stage only the files for this commit: `git add <files>`
3. Verify staged files match expected: `git diff --cached --name-only`
4. Execute commit using HEREDOC format:

```bash
git commit -m "$(cat <<'EOF'
type(scope): description

Optional body explaining the change.
EOF
)"
```

5. Verify commit succeeded before proceeding to next group

### 7. Handle Results

**Success**:

- Display summary of all commits created:
  ```
  Created 3 atomic commits:
  - abc1234 chore(config): add eslint rule for imports
  - def5678 refactor(auth): extract token validation logic
  - ghi9012 feat(auth): add OAuth2 support
  ```

**Failure**:

- If a commit fails (e.g., pre-commit hook): Stop immediately, report which commit failed
- Show remaining uncommitted groups
- Do not attempt to continue automatically

## Commit Message Standards

Follow conventional commits format: `type(scope): description`

| Type       | Description                                |
|------------|-------------------------------------------|
| `feat`     | New feature or capability                  |
| `fix`      | Bug fix                                    |
| `refactor` | Code restructuring without behavior change |
| `docs`     | Documentation only                         |
| `style`    | Formatting, whitespace, no code change     |
| `test`     | Adding or updating tests                   |
| `chore`    | Build, config, maintenance tasks           |
| `perf`     | Performance improvements                   |

Rules:

- **Scope**: Identifies affected area (e.g., `auth`, `api`, `ui`)
- **Description**: Imperative mood, max 50 characters, no period
- **Body**: Optional, max 200 characters, prefer bullet points

## Notes

- Always prefer more granular commits over fewer large ones
- Each commit should be independently buildable/testable when possible
- If changes are too intertwined to separate, create a single commit and note why
- Use English for all commit messages

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
