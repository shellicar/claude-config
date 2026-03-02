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

```bash
~/.claude/skills/git-commit/scripts/git-commit-info.sh
```

The script auto-detects the platform (GitHub or Azure DevOps) and project name from `git remote get-url origin`.

The script outputs structured sections: `BRANCH`, `MERGED_PR`, `STAGED_STAT`, `STATUS`, `RECENT_LOG`.

### 3. Analyse the gathered state

From the script output, check the following — stop and inform the Supreme Commander if any fail:

- **Merged PR**: If `MERGED_PR` shows a completed PR for this branch, STOP — the branch was already merged.
- **Branch protection**: If the convention has branch protection rules, check whether the current branch allows direct commits. If protected, offer to create a branch.
- **No staged changes**: If `STAGED_STAT` is empty, inform the Supreme Commander.
- **Unstaged/untracked changes**: If `STATUS` shows unstaged or untracked files, show the Supreme Commander and use `AskUserQuestion` with options like "Stage them", "Leave unstaged". If files are staged, re-run the gather script after staging to get the updated diff.

**Gitignored file check**: If you edited any files during this conversation, verify they are visible to git. Run `git check-ignore <file-path>` for any files you changed that don't appear in the status. If ignored, warn the Supreme Commander.

### 4. Secret and PII scanning

Load the `secret-scanning` skill and scan staged files before committing.

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

## Pre-commit Hook Failure

If the commit fails due to pre-commit hooks:

### Step 1: Identify available fixers

Read the hook configuration (e.g., `lefthook.yml`) and `package.json` scripts to determine which tools are configured and what fix commands are available. This is a quick read — do not investigate beyond these files. If it's not obvious what to run, ask the Supreme Commander.

### Step 2: Run automated fixers

Use CLI tools to fix issues. Do NOT manually edit files. Only run fixers on the files we have modified — not the entire project.

Get the list of changed files from `git diff --cached --name-only` and pass them to the fixer.

#### Biome

```bash
pnpm biome check --diagnostic-level=error --write <file1> <file2> ...
```

#### ESLint

```bash
pnpm run lint --fix -- <file1> <file2> ...
# or
pnpm run lint -- --fix <file1> <file2> ...
```

### Step 2: Re-stage and retry

Stage the fixed files, then create a **NEW commit** (do not amend — the previous commit didn't happen).

### Step 3: Verify

Verify with commands that do not flood output:

```bash
pnpm biome check --diagnostic-level=error
```

### Step 4: If automated fixers couldn't resolve everything

Check whether the remaining issues are in files **outside** the changeset (i.e., pre-existing issues in files we are not checking in).

- **Issues outside our changeset**: `--no-verify` is allowed, but you **MUST** ask the Supreme Commander for permission first.
- **Issues inside our changeset**: Either ask the Supreme Commander for permission to manually fix (explain what you would change), or hand over to the Supreme Commander. Mention all remaining issues.

### Strictly forbidden

- `--unsafe` or any biome unsafe fix flags — forbidden under **all** circumstances
- `npx` / `pnpx` — tools are already installed; using these wastes time downloading and may produce wrong results
- Manually editing files to pass hooks **without permission** — you may ask, but you do not fix without asking

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
