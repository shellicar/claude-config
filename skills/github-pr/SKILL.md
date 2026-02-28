---
name: github-pr
description: "Create or update a GitHub pull request with a summary of changes.\nTRIGGER when: creating PRs, updating PRs, pushing for review, or asked to open a PR on GitHub.\nDO NOT TRIGGER when: reading PR status, exploring PR history, or non-PR git operations."
allowed-tools: Bash(~/.claude/skills/github-pr/scripts/*)
---

# GitHub PR Workflow

**Scope:** Steps and CLI commands for creating or updating a GitHub pull request. PR format and conventions live in convention skills.

Create or update a pull request with a detailed summary of changes.

## Working Directory

Always `cd` to the project directory first, then use bare `git` and `gh` commands (e.g., `git status`, not `git -C /path status`). This ensures commands match auto-approve patterns in the user's permission settings.

## Script Dependencies

This skill uses helper scripts in `~/.claude/skills/github-pr/scripts/`:

| Script | Purpose | Fallback if Missing |
|--------|---------|---------------------|
| `git-ancestor.sh` | Finds base branch via merge-base analysis | Use `git merge-base HEAD <default-branch>` manually |
| `git-summary.sh` | Generates change summary (staged, commits, diff) | Run git commands directly |
| `git-context.sh` | Gets repository context | Use `git remote get-url origin` |

Convention detection is handled by the `detect-convention` skill.

If scripts are missing, fall back to manual git commands or ask the user for context.

## Usage

### 1. Verify Current Branch

```bash
git branch --show-current
```

If on the default branch, **STOP** — a PR cannot be created from the default branch. Ask the user to create a feature branch first.

Also check if the branch has already been merged (e.g. squash-merged via PR):

```bash
gh pr list --head <branch-name> --state merged --json number,title
```

If a merged PR exists for this branch, **STOP** — inform the user this branch was already merged. They need to pull and create a new branch for further work.

### 2. Detect Convention

Use the `detect-convention` skill to determine which convention applies.

Load the corresponding `<convention>-conventions` skill based on the convention name.

### 3. Determine Ancestor Branch

Run the ancestor detection script:

```bash
~/.claude/skills/github-pr/scripts/git-ancestor.sh
```

This finds the correct base branch using merge-base analysis, detecting epic branches when present.

### 4. Generate Change Summary

Run the summary script:

```bash
~/.claude/skills/github-pr/scripts/git-summary.sh
```

This outputs:
- Ancestor branch detected
- Staged changes
- Commits since ancestor
- Diff stats from ancestor

### 5. Create PR Content

**CVE/security branches** (`security/` prefix): Use the commit message as both the PR title and body.

**All other branches**: Based on loaded convention skill:
- **Title**: Short summary of the branch purpose (under 70 characters)
- **Description**: See style guide below
- **Work Items**: Link format per convention (e.g., `#123`, `AB#1234`)

#### PR Description Style Guide

See `writing-style` skill for the full style guide. Key points:
- Describe **what** was done, not **how** it was implemented
- `## Summary` heading with 3-5 bullet points maximum
- Short phrases, not full sentences
- If the title says it all, an empty body is fine

### 6. Resolve Milestone (GitHub)

You MUST load the `github-milestone` skill and resolve the milestone BEFORE creating the PR. The milestone is a required parameter for `gh pr create`.

Follow the milestone skill's workflow:
1. Check for open milestones
2. If one exists, use it
3. If none exists, ask the user which to create

### 7. Create or Update PR

Pass the body directly via `--body` with a quoted string. Do NOT use temp files, `--body-file`, HEREDOCs, or `$(cat ...)` substitution.

**GitHub** (create):
```bash
gh pr create --title "Title" --body "Description" --assignee @me --milestone "1.3" --label dependencies
```

Every `gh pr create` MUST include:
- `--assignee @me`
- `--milestone "<milestone>"` (resolved in step 6)
- `--label <label>` (when applicable, e.g. `dependencies` for maintenance releases)

**GitHub** (update):
```bash
gh pr edit --title "Title" --body "Description"
```

After creating a PR, **always link the PR URL** back to the user so they can review it.

**Azure DevOps** (via convention):
```bash
az repos pr create --title "Title" --description "Description"
# or
az repos pr update --id ID --title "Title" --description "Description"
```

## Auto-Merge (GitHub)

After creating a PR, use `AskUserQuestion` to offer auto-merge:

- "Enable auto-merge" - Merges automatically when checks pass
- "Manual merge" - Leave for manual merge later

If auto-merge selected:

```bash
gh pr merge --auto --squash
```

## Post-Creation Verification (GitHub)

After creating a PR (and optionally enabling auto-merge), verify the PR is not blocked. Add a todo item to track this.

### 1. Check PR Status

```bash
gh pr view <number> --json state,mergeable,mergeStateStatus,statusCheckRollup
```

Key fields:
- `mergeStateStatus`: `CLEAN` (ready to merge), `BLOCKED` (checks failing or rules preventing merge), `BEHIND` (needs rebase)
- `mergeable`: `MERGEABLE`, `CONFLICTING`, `UNKNOWN`
- `statusCheckRollup`: Array of check runs with `name`, `status`, `conclusion`

### 2. Diagnose Failures

If `mergeStateStatus` is `BLOCKED`, inspect the `statusCheckRollup` for any checks with `conclusion: FAILURE`:

```bash
# Get the run ID from the detailsUrl in statusCheckRollup, then:
gh run view <run-id> --log-failed
```

This shows the failed step's logs, which usually reveals the root cause (e.g., audit failure, test failure, lint error).

### 3. Report and Recommend

After diagnosis, report:
- Which check(s) failed
- The root cause from the logs
- Whether the failure is **introduced by this PR** or **pre-existing on the default branch**
- Recommended action (fix in this PR, fix in a separate PR first, etc.)

If the failure is pre-existing on the default branch, recommend fixing it in a separate branch/PR so it unblocks all PRs, not just this one.

## Post-Merge Cleanup (GitHub)

After a PR is merged, clean up branches:

### 1. Verify Branch Content is Merged

Check that the branch changes exist in the default branch (handles squash merges):

```bash
# Fetch latest
git fetch origin

# Get branch diff content
BASE=$(git merge-base HEAD origin/<default-branch>)
BRANCH_DIFF=$(git diff $BASE HEAD | sed -n '/^---/!p' | sed -n '/^+++/!p' | sed -n '/^@@/!p' | sed -n '/^index /!p')

# Check if the default branch contains the same changes
# (Compare against recent commits in the default branch)
```

Alternatively, use `~/dotfiles/git-check.sh <branch>` if available.

### 2. Delete Remote Branch

```bash
git push origin --delete <branch-name>
```

### 3. Prune Stale Remote References

```bash
git fetch -p
```

### 4. Delete Local Branch

```bash
git switch <default-branch>
git branch -D <branch-name>
```

### Post-Merge Flow

After merge is confirmed, use `AskUserQuestion` with **two questions**:

1. **Release**: "Create a release?" (triggers `github-release` skill)
   - "Create release" - Run github-release workflow
   - "Skip release" - No release now

2. **Cleanup**: "Clean up branches?"
   - "Clean up branches" - Delete remote and local branches, switch to default branch
   - "Keep branches" - Leave branches for manual cleanup

## Convention Requirements

Convention skills must define:
- `platform`: `github` or `azure-devops`
- `work_item_format`: How to link work items in PR description
- `pr_template`: Structure for PR description
