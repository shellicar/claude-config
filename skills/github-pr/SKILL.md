---
name: github-pr
description: Create or update a GitHub pull request with a summary of changes. Use when creating PRs, pushing for review, or asked to open a PR on GitHub.
allowed-tools: Bash(~/.claude/skills/github-pr/scripts/*)
---

# GitHub PR Workflow

Create or update a pull request with a detailed summary of changes.

## Script Dependencies

This skill uses helper scripts in `~/.claude/skills/github-pr/scripts/`:

| Script | Purpose | Fallback if Missing |
|--------|---------|---------------------|
| `detect-convention.sh` | Detects project convention from git remote | Ask user which convention to use |
| `git-ancestor.sh` | Finds base branch via merge-base analysis | Use `git merge-base HEAD main` manually |
| `git-summary.sh` | Generates change summary (staged, commits, diff) | Run git commands directly |
| `git-context.sh` | Gets repository context | Use `git remote get-url origin` |

If scripts are missing, fall back to manual git commands or ask the user for context.

## Usage

### 1. Verify Current Branch

```bash
git branch --show-current
```

If on `main` or `master`, **STOP** — a PR cannot be created from the default branch. Ask the user to create a feature branch first.

Also check if the branch has already been merged (e.g. squash-merged via PR):

```bash
gh pr list --head <branch-name> --state merged --json number,title
```

If a merged PR exists for this branch, **STOP** — inform the user this branch was already merged. They need to switch to main, pull, and create a new branch for further work.

### 2. Detect Convention

Run the detection script to determine which convention applies:

```bash
~/.claude/skills/github-pr/scripts/detect-convention.sh
```

This outputs the convention name (e.g., `shellicar`, `eagers`, `hopeventures`) or fails if no match.
Load the corresponding `<convention>-conventions` skill based on the output.

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

Based on loaded convention skill:
- **Title**: Short summary of the branch purpose
- **Description**: Detailed summary of changes, grouped by feature/area
- **Work Items**: Link format per convention (e.g., `#123`, `AB#1234`)

### 6. Create or Update PR

**GitHub** (via convention):
```bash
gh pr create --title "Title" --body "Description"
# or
gh pr edit --title "Title" --body "Description"
```

**Azure DevOps** (via convention):
```bash
az repos pr create --title "Title" --description "Description"
# or
az repos pr update --id ID --title "Title" --description "Description"
```

## Milestones (GitHub)

If a version is known (e.g., from `github-version` skill), create/use a milestone:

```bash
# Check if milestone exists
gh api repos/{owner}/{repo}/milestones --jq '.[] | select(.title=="1.2.1")'

# Create if needed
gh api repos/{owner}/{repo}/milestones -f title="1.2.1"

# Create PR with milestone
gh pr create --title "Title" --body "Description" --milestone "1.2.1"
```

### When Version Is Not Known

If the PR is being created without a version bump (e.g., changes only, version management later), use `AskUserQuestion` to confirm:

```text
No version has been determined for this PR.

Would you like to:
1. Proceed without a milestone (version management later)
2. Run github-version first to determine the version
```

This ensures the user consciously decides whether to proceed without a milestone.

## Auto-Merge (GitHub)

After creating a PR, use `AskUserQuestion` to offer auto-merge:

- "Enable auto-merge" - Merges automatically when checks pass
- "Manual merge" - Leave for manual merge later

If auto-merge selected:

```bash
gh pr merge --auto --squash
```

## Post-Merge Cleanup (GitHub)

After a PR is merged, clean up branches:

### 1. Verify Branch Content is Merged

Check that the branch changes exist in main (handles squash merges):

```bash
# Fetch latest
git fetch origin

# Get branch diff content
BASE=$(git merge-base HEAD origin/main)
BRANCH_DIFF=$(git diff $BASE HEAD | sed -n '/^---/!p' | sed -n '/^+++/!p' | sed -n '/^@@/!p' | sed -n '/^index /!p')

# Check if main contains the same changes
# (Compare against recent commits in main)
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
git switch main
git branch -D <branch-name>
```

### Post-Merge Flow

After merge is confirmed, use `AskUserQuestion` with **two questions**:

1. **Release**: "Create a release?" (triggers `github-release` skill)
   - "Create release" - Run github-release workflow
   - "Skip release" - No release now

2. **Cleanup**: "Clean up branches?"
   - "Clean up branches" - Delete remote and local branches, switch to main
   - "Keep branches" - Leave branches for manual cleanup

## Convention Requirements

Convention skills must define:
- `platform`: `github` or `azure-devops`
- `work_item_format`: How to link work items in PR description
- `pr_template`: Structure for PR description
