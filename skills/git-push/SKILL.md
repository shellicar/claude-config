---
name: git-push
description: Push commits to remote with secret and PII scanning. Use when pushing code, after committing, or before creating a PR.
---

# Git Push Workflow

**Scope:** Git CLI commands for pushing, secret scanning gates, and divergence checks. Convention-specific rules live in convention skills.

Push local commits to the remote with mandatory secret and PII scanning.

## Working Directory

Always `cd` to the project directory first, then use bare `git` commands (e.g., `git push`, not `git -C /path push`). This ensures commands match auto-approve patterns in the user's permission settings.

## Prerequisites

Load the `secret-scanning` skill before proceeding. Its pattern tables define what to scan for.

## Steps

### 1. Detect Convention

If not already known from the calling workflow (e.g. `git-commit`), use the `detect-convention` skill to determine the convention and default branch.

If it outputs a convention name, load the corresponding `<convention>-conventions` skill.
If it fails, proceed without convention-specific rules.

### 2. Verify Current Branch

```bash
git branch --show-current
```

If a convention is loaded, follow its branch protection rules to determine whether direct pushes are allowed to this branch. Generally, branches like `main` or `epic/*` are protected and require PRs.

### 3. Identify Commits to Push

**Existing upstream:**

```bash
git log @{u}..HEAD --oneline
```

**New branch (no upstream):**

```bash
git log --oneline -10
```

Confirm scope with the Supreme Commander for new branches.

If there are no commits to push, inform the Supreme Commander and stop.

### 4. Secret and PII Scanning

Review each commit's diff individually:

```bash
git show <hash>
```

Load the `secret-scanning` skill and apply its pattern tables and Finding Disposition Process to each commit's diff.

**Important**: A secret added in one commit and removed in a later commit is still in the pushed history. Each commit must be clean.

Do NOT silently push code containing matches. Present findings and wait for confirmation from the Supreme Commander before proceeding.

### 5. Check for Divergence

```bash
git rev-list --left-right --count @{u}...HEAD
```

Output is `<behind>\t<ahead>`.

- **Behind is 0**: Safe to push with `git push`
- **Behind is non-zero**: Branch has diverged from the remote — **STOP** and inform the Supreme Commander, as this may require manual intervention (rebase, merge, or force push)

For new branches (no upstream), this check is skipped.

### 6. Push

```bash
git push
```

For new branches:

```bash
git push -u origin <branch-name>
```

### 7. Verify Push

```bash
git log @{u}..HEAD --oneline
```

Should show no commits (all pushed). If commits remain, report the issue.

### 8. Offer to Create PR

Use `AskUserQuestion` with options like "Create PR" and "Skip".

If the Supreme Commander requests a PR, invoke the appropriate skill based on the loaded convention:
- **GitHub conventions** → use the `github-pr` skill
- **Azure DevOps conventions** → use the `azure-devops-repos` skill

If no convention is loaded, infer from the git remote URL:
- `github.com` → `github-pr`
- `dev.azure.com` → `azure-devops-repos`
