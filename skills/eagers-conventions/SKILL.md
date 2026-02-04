---
name: eagers-conventions
description: Git conventions for Eagers Automotive projects (Azure DevOps)
user-invocable: false
---

# Eagers Conventions

Git and PR conventions for Eagers Automotive projects.

## Detection

Match when:
- Remote URL contains `dev.azure.com/eagersautomotive/`
- Local email ends with `@eagersa.com.au`

## Platform

- **Platform**: Azure DevOps
- **CLI**: `az repos` and `az boards`
- **Reference**: See `azure-devops` skill for CLI command syntax

## Branch Naming

Project-specific (varies by project):
- `epic/<name>`
- `feature/<name>`
- `fix/<name>`
- `fix/<work-item-id>/<name>`

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

## Workflow

1. Identify or create the **Feature** under the relevant **Epic**
2. Create **PBIs** under the Feature, assign to current sprint
3. Create **Tasks** under each PBI, assign to current sprint
4. Create PR referencing PBIs in description
5. Work items auto-link to PR

---

## Area Paths & Iterations

## Area Paths & Iterations

- **Area Path**: `{Project}\{Area}`
- **Parent Iteration**: `{Project}\{Area}` (for Features and above)
- **Sprint Iterations**: `{Project}\{Area}\{Sprint}`, `{Project}\{Area}\{Sprint}`, etc.

### Assignment Rules

| Work Item Type | Area Path | Iteration Path |
|----------------|-----------|----------------|
| Initiative | `{Project}\{Area}` | `{Project}\{Area}` (parent) |
| Epic | `{Project}\{Area}` | `{Project}\{Area}` (parent) |
| Feature | `{Project}\{Area}` | `{Project}\{Area}` (parent) |
| PBI | `{Project}\{Area}` | `{Project}\{Area}\<current sprint>` |
| Task | `{Project}\{Area}` | `{Project}\{Area}\<current sprint>` |

### Finding Current Sprint

```bash
az boards iteration project list --project "{Project}" --path "\\{Project}\\Iteration\\{Area}" --depth 2 -o json | jq '.children[] | {name: .name, start: .attributes.startDate, finish: .attributes.finishDate}'
```

The current sprint is where today's date falls between `startDate` and `finishDate`.

### Example Work Item Hierarchy

```
Initiative #1001: Application Name
  └─ Epic #1002: Major Feature
       └─ Feature #1003: Specific capability
            └─ PBI #1004: Deliverable work
                 ├─ Task #1005: Implementation step 1
                 ├─ Task #1006: Implementation step 2
                 └─ Task #1007: Implementation step 3
```

### CLI Examples

```bash
# Create work item
az boards work-item create --type "Task" --title "My task" --project "{Project}" --area "{Project}\\{Area}" --iteration "{Project}\\{Area}\\{Sprint}"

# Update iteration
az boards work-item update --id 1234 --fields "System.IterationPath={Project}\\{Area}\\{Sprint}"

# List iterations
az boards iteration project list --project "{Project}" -o json | jq '.children[] | {name: .name, path: .path}'
```
