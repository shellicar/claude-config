---
name: hopeventures-conventions
description: Git conventions for Hope Ventures projects (Azure DevOps)
user-invocable: false
---

# Hope Ventures Conventions

Git and PR conventions for Hope Ventures projects (projects).

## Detection

Match when:
- Remote URL contains `dev.azure.com/hopeventures/` (case insensitive)
- Working directory under `$HOME/repos/HopeVentures/`

## Platform

- **Platform**: Azure DevOps
- **CLI**: `az repos` and `az boards`
- **Reference**: See `azure-devops` skill for CLI command syntax

## Branch Naming

- `feature/<name>`
- `fix/<name>`
- `main` (default branch)

## Commit Messages

- Concise, single line
- Imperative mood
- Work item reference optional in commits (required in PR)

## PR Description Format

```markdown
## Summary

Brief description of the changes.

## Related Work Items

#1234

#5678

## Changes

- Change 1
- Change 2

## Test Plan

- [ ] Test case 1
- [ ] Test case 2
```

**Note**: Work item links (`#1234`) must be on separate lines with blank lines between for proper rendering.

## Work Item Linking

- **Format**: `#1234` (Azure DevOps auto-links)
- **In PR description**: Required
- **In commits**: Optional

## CLI Commands

```bash
# Create PR
az repos pr create --title "Title" --description "$(cat description.md)"

# Update PR
az repos pr update --id ID --title "Title" --description "$(cat description.md)"

# List PRs
az repos pr list --status active

# View PR
az repos pr show --id ID
```
