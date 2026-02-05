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

- `feature/<area>/<descriptive-name>` - e.g., `feature/facilitation/attendance-tracking`
- `fix/<area>/<descriptive-name>` - e.g., `fix/facilitation/update-group-view-on-facilitator-licence-change`
- `main` (default branch)

Use `git switch -c <branch>` to create branches (not `git checkout` - it's blocked to prevent accidental data loss).

## Direct Commits to Main

The following repos allow direct commits to main (no branch required):
- Repos ending with `-Documentation` 

## Commit Messages

- Concise, single line
- Stakeholder-friendly - focus on "what changed" not implementation details
- Imperative mood
- Work item reference optional in commits (required in PR)
- **No co-author** - do not include `Co-Authored-By` lines

**Good**: `Recalculate group status when facilitator licence changes`
**Bad**: `Add handleFacilitator to ProgramGroupViewProcessor`

## PR Description Format

```markdown
## Summary

Brief description of the changes - focus on "why" and "what", not implementation details.

## Related Work Items

#1234

#5678

## Changes

- Change 1 (describe the effect, not the code)
- Change 2
```

**Notes**:
- Work item links (`#1234`) must be on separate lines with blank lines between for proper rendering
- Test Plan section is optional - omit unless explicitly needed
- Changes should describe effects, not implementation (e.g., "Recalculate group status when facilitator profile updates" not "Wire up handler in ProcessViewHandler")

## Work Item Linking

- **Format**: `#1234` (Azure DevOps auto-links)
- **In PR description**: Required
- **In commits**: Optional

## CLI Commands

```bash
# Create PR
az repos pr create --title "Title" --description "$(cat description.md)"

# Set auto-complete (always do this after creating PR)
az repos pr update --id ID --auto-complete true

# Link tasks to PR
az repos pr work-item add --id PR_ID --work-items TASK_ID

# Update PR
az repos pr update --id ID --title "Title" --description "$(cat description.md)"

# List PRs
az repos pr list --status active

# View PR
az repos pr show --id ID
```

**Auto-complete**: CONFIRM WITH USER before setting. The merge strategy (squash vs merge) may be configured in Azure DevOps UI - need to verify correct settings are in place before using.
