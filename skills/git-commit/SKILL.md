---
name: git-commit
description: "Create a git commit with a concise message.\nTRIGGER when: committing changes, asked to commit, after completing a task, or staging files for commit.\nDO NOT TRIGGER when: reading git status, exploring history, or non-commit git operations."
---

# Git Commit Workflow

**Scope:** Git CLI commands for committing, their required sequence, and why each step is not skippable. Convention-specific rules live in convention skills.

Create a commit from staged changes with a concise, single-line message.

## Working Directory

Always `cd` to the project directory first, then use bare `git` commands (e.g., `git status`, not `git -C /path status`). This ensures commands match auto-approve patterns in the user's permission settings.

## Steps

### 1. Detect convention

Use the `detect-convention` skill to determine the convention and default branch.

If it outputs a convention name, load the corresponding `<convention>-conventions` skill.
If it fails, proceed without convention-specific rules.

### 2. Gather git state

Run the gather script to collect all git state in one call:

**GitHub:**
```bash
~/.claude/skills/git-commit/scripts/git-commit-info.sh --github
```

**Azure DevOps:**
```bash
~/.claude/skills/git-commit/scripts/git-commit-info.sh --azure-devops --project <Project>
```

**Unknown/no convention:**
```bash
~/.claude/skills/git-commit/scripts/git-commit-info.sh
```

The script outputs structured sections: `BRANCH`, `MERGED_PR`, `STAGED_STAT`, `STATUS`, `STAGED_DIFF`, `RECENT_LOG`.

### 3. Analyse the gathered state

From the script output, check the following — stop and inform the Supreme Commander if any fail:

- **Merged PR**: If `MERGED_PR` shows a completed PR for this branch, STOP — the branch was already merged.
- **Branch protection**: If the convention has branch protection rules, check whether the current branch allows direct commits. If protected, offer to create a branch.
- **No staged changes**: If `STAGED_STAT` is empty, inform the Supreme Commander.
- **Unstaged/untracked changes**: If `STATUS` shows unstaged or untracked files, show the Supreme Commander and use `AskUserQuestion` with options like "Stage them", "Leave unstaged". If files are staged, re-run the gather script after staging to get the updated diff.

**Gitignored file check**: If you edited any files during this conversation, verify they are visible to git. Run `git check-ignore <file-path>` for any files you changed that don't appear in the status. If ignored, warn the Supreme Commander.

### 4. Secret and PII scanning

Load the `secret-scanning` skill and apply its pattern tables and Finding Disposition Process to the `STAGED_DIFF` from the gather output.

If findings exist, present them and wait for confirmation before proceeding. Do not silently commit files containing matches.

### 5. Generate commit message

- Concise, single line
- Imperative mood ("Add feature" not "Added feature")
- No period at end
- Keep under 50 characters (hard limit: 72)
- Detail belongs in PRs, not commits

### 6. Confirm and commit

Use `AskUserQuestion` with the proposed commit message and options like "Commit", "Edit message", "Cancel".

```bash
git commit -m "message"
```

### 7. Verify and offer push

```bash
git log -1 --format="%h %s"
```

Confirm the commit was created with the expected message.

Use `AskUserQuestion` with options like "Push" and "Don't push". If push requested, invoke the `git-push` skill.

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
