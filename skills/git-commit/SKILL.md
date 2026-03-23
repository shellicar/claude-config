---
name: git-commit
description: |
  WHAT: Enforces the commit sequence: branch check, staged file review, secret scanning, and message format.
  WHY: Skipping steps causes commits to the wrong branch or wrong files, both of which require serious cleanup to undo.
  WHEN: TRIGGER when committing changes or staging files.
  DO NOT TRIGGER for reading status or exploring history.
metadata:
  category: workflow
---

# Git Commit Workflow

**Scope:** Git CLI commands for committing, their required sequence, and why each step is not skippable. Convention-specific rules live in convention skills.

Create a commit from staged changes with a concise, single-line message.

## Working Directory

Always `cd` to the project directory first, then use bare `git` commands (e.g., `git status`, not `git -C /path status`). This ensures commands match auto-approve patterns in the user's permission settings.

## Steps

### 1. Gather git state

Run the gather script to collect all git state in one call:

```bash
~/.claude/skills/git-commit/scripts/git-commit-info.sh
```

The script auto-detects the platform (GitHub or Azure DevOps) and project name from `git remote get-url origin`. It also calls `detect-convention` internally.

The script outputs a single JSON object with fields: `platform`, `project`, `convention`, `branch`, `protected_branches`, `open_pr`, `merged_pr`, `staged_files`, `status`, `recent_log`.

After running the script, load the `<convention>-conventions` skill if `.convention` is non-null. If null, proceed without convention-specific rules.

### 2. Analyse the gathered state

From the JSON output, check the following — stop and inform the Supreme Commander if any fail:

- **Branch protection** *(check this first)*: If `.branch` appears in `.protected_branches` (and the array is non-empty), **STOP immediately** — do not proceed. Inform the Supreme Commander that direct commits to this branch are not allowed, and offer to create a new branch.
- **Merged PR**: If `.merged_pr` is non-empty, STOP — the branch was already merged.
- **No staged changes**: If `.staged_files` is empty (`[]`), inform the Supreme Commander.
- **Unstaged/untracked changes**: If `.status.unstaged` or `.status.untracked` is non-empty, show the Supreme Commander and use `AskUserQuestion` with options like "Stage them", "Leave unstaged". If files are staged, re-run the gather script after staging to get the updated diff.

**Gitignored file check**: If you edited any files during this conversation, verify they are visible to git. Run `git check-ignore <file-path>` for any files you changed that don't appear in the status. If ignored, warn the Supreme Commander.

### 3. Secret and PII scanning

Load the `secret-scanning` skill and scan staged files before committing.

If findings exist, present them and wait for confirmation before proceeding. Do not silently commit files containing matches.

### 4. Generate commit message

Load the `writing-style` skill.

- Concise, single line
- Imperative mood ("Add feature" not "Added feature")
- No period at end
- Keep under 50 characters (hard limit: 72)
- Detail belongs in PRs, not commits

### 5. Confirm and commit

Use `AskUserQuestion` with the proposed commit message and options like "Commit", "Edit message", "Cancel".

```bash
git commit -m "message"
```

### 6. Verify and offer push

```bash
git log -1 --format="%h %s"
```

Confirm the commit was created with the expected message.

Use `AskUserQuestion` with options like "Push" and "Don't push". If push requested, invoke the `git-push` skill.

## Pre-commit Hook Failure

If the commit fails due to pre-commit hooks:

### Strictly forbidden

These are non-negotiable. Read them BEFORE attempting any fix.

- `--unsafe` or any biome unsafe fix flags — forbidden under **all** circumstances
- `npx` / `pnpx` — tools are already installed; using these wastes time downloading and may produce wrong results
- `git add -A` / `git add .` — stages everything including unrelated changes. Always `git add` specific files.
- Manually editing files to pass hooks **without permission** — you may ask, but you do not fix without asking
- `--filter` for running package scripts — `cd` into the package directory instead
- If a fixer command fails (wrong invocation, path issues, unexpected error), **STOP and ask the Supreme Commander**. Do not improvise alternative tools or workarounds.

### Step 1: Identify available fixers

Read the hook configuration (e.g., `lefthook.yml`) and `package.json` scripts to determine which tools are configured and what fix commands are available. This is a quick read — do not investigate beyond these files. If it's not obvious what to run, ask the Supreme Commander.

### Step 2: Run automated fixers

Use CLI tools to fix issues. Do NOT manually edit files. Only run fixers on the files we have modified — not the entire project.

Get the list of changed files from `git diff --cached --name-only` and pass them to the fixer.

#### Biome

Run from the project root:

```bash
pnpm biome check --diagnostic-level=error --write <file1> <file2> ...
```

#### ESLint

`cd` into the package directory that owns the files, then run with paths relative to that package:

```bash
cd packages/<package-name>
pnpm eslint --fix <relative-file1> <relative-file2> ...
```

Do NOT use `pnpm run lint` — the script wraps `eslint .` which conflicts with passing individual files.
Do NOT use `--filter` — it does not reliably pass arguments through to the underlying script.

### Step 3: Re-stage and retry

Stage the fixed files, then create a **NEW commit** (do not amend — the previous commit didn't happen).

### Step 4: Verify

Verify with commands that do not flood output:

```bash
pnpm biome check --diagnostic-level=error
```

### Step 5: If automated fixers couldn't resolve everything

Check whether the remaining issues are in files **outside** the changeset (i.e., pre-existing issues in files we are not checking in).

- **Issues outside our changeset**: `--no-verify` is allowed, but you **MUST** ask the Supreme Commander for permission first.
- **Issues inside our changeset**: Either ask the Supreme Commander for permission to manually fix (explain what you would change), or hand over to the Supreme Commander. Mention all remaining issues.

When files are edited, IDE diagnostics may appear. Handle them as follows:

- **Errors**: Report to the user and address before committing
- **Warnings/Information**: Ignore silently (e.g., spell-checker warnings)
- **Exception**: If a warning appears critical or high-severity (e.g., security issue, likely runtime error), you MAY mention it

Do NOT mention trivial non-error diagnostics to the user.

## Convention Hooks

Convention skills may define:

- Work item ID in commit message (e.g., `AB#1234: Add feature`)
- Branch name requirements

## No Commit Prefixes

Conventional Commits is a spec designed for automated version bumping — `feat:` triggers a minor, `fix:` triggers a patch, `BREAKING CHANGE` triggers a major. These projects do not use `semantic-release`, `commitlint`, or any tooling that reads commit prefixes. The prefixes serve no purpose here and make commit messages harder to read.

Do not use `feat:`, `fix:`, `chore:`, `build:`, `ci:`, `docs:`, `perf:`, `refactor:`, `revert:`, `style:`, `test:`, or any `type:` or `type(scope):` pattern.
