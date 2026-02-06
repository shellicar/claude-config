---
name: git-commit
description: Create a git commit with a concise message. Use when committing changes, asked to commit, or after completing a task.
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
    - Use `AskUserQuestion` with options like "Stage them", "Leave unstaged"
    - Stage additional files if requested

3. **Verify staging is correct**

    After staging, run both:
    ```bash
    git diff --staged --stat
    git diff --stat
    ```

    - Confirm staged changes match what was intended
    - If unstaged changes remain, verify they are expected (i.e. files the user chose to leave unstaged)
    - If a file you staged still shows unstaged changes, investigate — it may have been modified after staging
    - Use `AskUserQuestion` to confirm with the user before proceeding

4. **Read the staged diff content**

    ```bash
    git diff --staged
    ```

5. **Detect convention**
    Run the detection script:

    ```bash
    ~/.claude/skills/github-pr/scripts/detect-convention.sh
    ```

    If it outputs a convention name, load the corresponding `<convention>-conventions` skill.
    If it fails, proceed without convention-specific rules.

6. **Check branch protection**

    ```bash
    git branch --show-current
    ```

    If on `main` or `master`:
    - If convention is `shellicar-config` → allowed, continue
    - Otherwise → **STOP** and ask user to create a new branch

    Do NOT commit directly to main/master (except for config repos). Offer to create a branch:
    ```bash
    git checkout -b <branch-name>
    ```

7. **Generate commit message**
    - Concise, single line
    - Imperative mood ("Add feature" not "Added feature")
    - No period at end
    - Keep under 50 characters (hard limit: 72)
    - Detail belongs in PRs, not commits

8. **Show the user the proposed commit message and ask for confirmation**

    Use `AskUserQuestion` with options like "Commit", "Edit message", "Cancel"

9. **Commit**

    ```bash
    git commit -m "message"
    ```

10. **Verify commit**

    ```bash
    git log -1 --format="%h %s"
    ```

    Confirm the commit was created with the expected message.

    Then check if the branch can be pushed cleanly:

    ```bash
    git rev-list --left-right --count @{u}...HEAD
    ```

    Output is `<behind>\t<ahead>`. If the first number (behind) is `0`, a regular `git push` will work. If it is non-zero, the branch has diverged from the remote — **STOP** and inform the user, as this may require manual intervention.

11. **Pre-push review**

    List commits that will be pushed:

    ```bash
    git log @{u}..HEAD --oneline
    ```

    If no upstream exists (new branch), use `git log --oneline -10` and confirm scope with user.

    Then review each commit's diff individually:

    ```bash
    git show <hash>
    ```

    Check **every** commit for:
    - No sensitive content (secrets, credentials, API keys, tokens, `.env` files)
    - No unintended files included
    - All changes are accounted for

    A secret added in one commit and removed in a later commit is still in the pushed history. Each commit must be clean.

    Report findings to the user before pushing.

12. **Push**

    ```bash
    git push
    ```

## IDE Diagnostics

When files are edited, IDE diagnostics may appear. Handle them as follows:

- **Errors**: Report to the user and address before committing
- **Warnings/Information**: Ignore silently (e.g., spell-checker warnings)
- **Exception**: If a warning appears critical or high-severity (e.g., security issue, likely runtime error), you MAY mention it

Do NOT mention trivial non-error diagnostics to the user.

## Convention Hooks

Convention skills may define:

- Work item ID in commit message (e.g., `AB#1234: Add feature`)
- Prefix conventions (e.g., `feat:`, `fix:`)
- Branch name requirements
