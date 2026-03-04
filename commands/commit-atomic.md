---
description: Smart atomic commit tool. Analyzes all changes, groups them logically, and creates atomic commits.
allowed-tools: Task, Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Bash(git reset HEAD:*), AskUserQuestion
argument-hint: [--dry-run]
model: sonnet
---

# /hxm:commit-atomic - Smart Atomic Commit Tool

CRITICAL: Follow the Process section exactly - this tool analyzes ALL changes (staged and unstaged), groups them
logically, and creates multiple atomic commits. Each commit follows conventional commit standards.

## Usage

```bash
/hxm:commit-atomic [--dry-run]
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
- Otherwise: Ask user to confirm with AskUserQuestion:
  - "Proceed with X commits?" with options: "Yes, execute all" / "Let me review first"
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
