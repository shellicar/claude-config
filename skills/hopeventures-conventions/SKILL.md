---
name: hopeventures-conventions
description: Git conventions for Hope Ventures on Azure DevOps. Loaded when detected as the active convention.
user-invocable: false
---

# Hope Ventures Conventions

**Scope:** Git branch, commit, and PR conventions specific to Hope Ventures projects on Azure DevOps.

Git and PR conventions for Hope Ventures projects.

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

- Concise, single line, imperative mood
- Work item reference optional in commits (required in PR)
- See `writing-style` skill for tone and examples

## PR Description Format

Follow the `writing-style` skill for content. Use this template:

```markdown
## Summary

Brief description of the changes.

## Related Work Items

#1234

#5678

## Changes

- Change 1
- Change 2
```

**Notes**:
- Work item links (`#1234`) must be on separate lines with blank lines between for proper rendering
- Test Plan section is optional — omit unless explicitly needed

## Work Item Linking

See `azure-devops-repos` skill for the full PR completion workflow and CLI commands.

- **PR description** → Reference **PBIs** using `#1234` format
- **CLI linking** → Link **Tasks** via `az repos pr work-item add`
- **In commits**: Work item references are optional
