---
name: commit
description: Create a git commit with a concise message based on staged changes
---

# Git Commit Workflow

Create a commit from staged changes with a concise, single-line message.

## Steps

1. **Check for staged changes**
   ```bash
   git diff --staged --stat
   ```
   If nothing staged, inform the user.

2. **Check for unstaged changes**
   ```bash
   git diff --stat
   ```
   If unstaged changes exist:
   - Show the user WHAT the unstaged changes are (diff content, not just file names)
   - Ask if they forgot to stage them or intentionally want to leave them out
   - Stage additional files if requested

3. **Read the staged diff content**
   ```bash
   git diff --staged
   ```

4. **Detect conventions** (optional)
   Check for applicable convention skill based on:
   ```bash
   git remote get-url origin
   git config --local user.email
   ```
   Load convention skill if matched for commit message rules.

5. **Generate commit message**
   - Concise, single line
   - Imperative mood ("Add feature" not "Added feature")
   - No period at end
   - Detail belongs in PRs, not commits

6. **Show the user the proposed commit message and ask for confirmation**

7. **Commit**
   ```bash
   git commit -m "message"
   ```

## Convention Hooks

Convention skills may define:
- Work item ID in commit message (e.g., `AB#1234: Add feature`)
- Prefix conventions (e.g., `feat:`, `fix:`)
- Branch name requirements
