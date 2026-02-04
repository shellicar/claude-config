---
name: pr
description: Create or update a pull request with a summary of all changes since the ancestor branch
allowed-tools: Bash(~/.claude/skills/git-pr/scripts/*)
---

# Git PR Workflow

Create or update a pull request with a detailed summary of changes.

## Usage

### 1. Detect Convention

Run the detection script to determine which convention applies:

```bash
~/.claude/skills/git-pr/scripts/detect-convention.sh
```

This outputs the convention name (e.g., `shellicar`, `eagers`, `hopeventures`) or fails if no match.
Load the corresponding `<convention>-conventions` skill based on the output.

### 2. Determine Ancestor Branch

Run the ancestor detection script:

```bash
~/.claude/skills/git-pr/scripts/git-ancestor.sh
```

This finds the correct base branch using merge-base analysis, detecting epic branches when present.

### 3. Generate Change Summary

Run the summary script:

```bash
~/.claude/skills/git-pr/scripts/git-summary.sh
```

This outputs:
- Ancestor branch detected
- Staged changes
- Commits since ancestor
- Diff stats from ancestor

### 4. Create PR Content

Based on loaded convention skill:
- **Title**: Short summary of the branch purpose
- **Description**: Detailed summary of changes, grouped by feature/area
- **Work Items**: Link format per convention (e.g., `#123`, `AB#1234`)

### 5. Create or Update PR

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

If a version is known (e.g., from `version-management` skill), create/use a milestone:

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
2. Run version-management first to determine the version
```

This ensures the user consciously decides whether to proceed without a milestone.

## Convention Requirements

Convention skills must define:
- `platform`: `github` or `azure-devops`
- `work_item_format`: How to link work items in PR description
- `pr_template`: Structure for PR description
