---
name: git-commit
description: Create a git commit with a concise message. Use when committing changes, asked to commit, or after completing a task.
---

# Git Commit Workflow

**Scope:** Git CLI commands for committing, their required sequence, and why each step is not skippable. Convention-specific rules live in convention skills.

Create a commit from staged changes with a concise, single-line message.

## Why Steps Are Not Skippable

The Supreme Commander works interactively — the working tree, staging area, and even the branch can change between any two steps. Time may pass between interactions; between asking about unstaged files and verifying staging, the Supreme Commander may have shipped an entire feature, switched branches, or edited files externally. Steps that appear redundant (e.g., re-checking staging) exist as verification gates to catch changes that happened in the meantime. Do not optimise them away.

## Working Directory

Always `cd` to the project directory first, then use bare `git` commands (e.g., `git status`, not `git -C /path status`). This ensures commands match auto-approve patterns in the user's permission settings.

## Steps

1. **Detect convention**

    Use the `detect-convention` skill to determine the convention and default branch.

    If it outputs a convention name, load the corresponding `<convention>-conventions` skill.
    If it fails, proceed without convention-specific rules.

2. **Verify current branch**

    ```bash
    git branch --show-current
    ```

    Check if the branch has already been merged:

    **GitHub:**
    ```bash
    gh pr list --head <branch-name> --state merged --json number,title
    ```

    **Azure DevOps:**
    ```bash
    az repos pr list --source-branch <branch-name> --status completed --project <Project> -o json
    ```

    If a merged PR exists for this branch, **STOP** — inform the Supreme Commander this branch was already merged. They need to pull and create a new branch for further work.

3. **Check branch protection**

    If a convention is loaded, follow its branch protection rules to determine whether the current branch allows direct commits.

    If no convention is loaded, generally branches like `main` or `epic/*` are protected. Check whether the branch is a default/protected branch and ask the Supreme Commander before committing directly.

    If the branch is protected, offer to create a branch:
    ```bash
    git checkout -b <branch-name>
    ```

4. **Check for staged changes**

    ```bash
    git diff --staged --stat
    ```

    If nothing staged, inform the Supreme Commander.

5. **Check for unstaged, untracked, and gitignored changes**

    ```bash
    git status
    ```

    If unstaged or untracked changes exist:
    - Show the Supreme Commander WHAT the changes are (diff content for modified files, file list for untracked)
    - Use `AskUserQuestion` with options like "Stage them", "Leave unstaged"
    - Stage additional files if requested

    **Gitignored file check**: If you edited any files during this conversation, verify they are visible to git. A file may be gitignored (by `.gitignore` or global gitignore) and silently excluded from `git status`. To check, run:

    ```bash
    git check-ignore <file-path>
    ```

    If a file you edited is ignored, warn the Supreme Commander — they may need to `git add -f` it. This is especially important for files like `.claude/CLAUDE.md` or other config files that may be globally gitignored but intended for the repo.

6. **Verify staging is correct**

    After staging, run:
    ```bash
    git diff --staged --stat
    git status
    ```

    - Confirm staged changes match what was intended
    - If unstaged or untracked changes remain, verify they are expected (i.e. files the user chose to leave unstaged)
    - If a file you staged still shows unstaged changes, investigate — it may have been modified after staging
    - Use `AskUserQuestion` to confirm with the user before proceeding

7. **Read the staged diff content**

    ```bash
    git diff --staged
    ```

8. **Secret and PII scanning**

    Load the `secret-scanning` skill and apply its pattern tables and Finding Disposition Process to the staged diff from step 7.

    If findings exist, present them and wait for confirmation before proceeding. Do not silently commit files containing matches.

9. **Generate commit message**
    - Concise, single line
    - Imperative mood ("Add feature" not "Added feature")
    - No period at end
    - Keep under 50 characters (hard limit: 72)
    - Detail belongs in PRs, not commits

10. **Show the proposed commit message and ask for confirmation**

    Use `AskUserQuestion` with options like "Commit", "Edit message", "Cancel"

11. **Commit**

    ```bash
    git commit -m "message"
    ```

12. **Verify commit**

    ```bash
    git log -1 --format="%h %s"
    ```

    Confirm the commit was created with the expected message.

13. **Offer to push**

    Use `AskUserQuestion` with options like "Push" and "Don't push".

    If push requested, invoke the `git-push` skill to handle pre-push scanning, divergence checks, and push execution.

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
