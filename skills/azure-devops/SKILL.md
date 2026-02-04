---
name: azure-devops
description: Azure DevOps CLI reference for work items and PRs
user-invocable: false
---

# Azure DevOps CLI Reference

Generic CLI commands for Azure DevOps work items and PRs.

## Work Items

```bash
# Show work item
az boards work-item show --id <ID>

# Show specific fields only
az boards work-item show --id <ID> --expand none -o json | jq '{id: .id, type: .fields."System.WorkItemType", title: .fields."System.Title", areaPath: .fields."System.AreaPath", iterationPath: .fields."System.IterationPath", parent: .fields."System.Parent"}'

# Query recent work items
az boards query --wiql "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.CreatedDate] >= @Today - 7 ORDER BY [System.Id] DESC" -o table

# Query children of a work item
az boards query --wiql "SELECT [System.Id], [System.Title], [System.WorkItemType] FROM WorkItems WHERE [System.Parent] = <PARENT_ID>" -o json | jq '.[] | {id: .fields."System.Id", type: .fields."System.WorkItemType", title: .fields."System.Title"}'

# Create work item
az boards work-item create --type "Task" --title "Title" --project "<Project>" --area "<Area>" --iteration "<Iteration>"

# Update work item fields
az boards work-item update --id <ID> --fields "System.IterationPath=<Iteration>"

# Add parent relationship
az boards work-item relation add --id <ID> --relation-type "parent" --target-id <PARENT_ID>
```

## Iterations & Areas

```bash
# List project iterations
az boards iteration project list --project "<Project>" -o json | jq '.children[] | {name: .name, path: .path}'

# List child iterations (sprints)
az boards iteration project list --project "<Project>" --path "<Path>" --depth 2 -o json | jq '.children[] | {name: .name, path: .path, startDate: .attributes.startDate, finishDate: .attributes.finishDate}'

# List project area paths
az boards area project list --project "<Project>" -o json | jq '.children[] | {name: .name, path: .path}'
```

## Pull Requests

```bash
# List active PRs
az repos pr list --status active --repository <Repo> --project <Project> -o table

# Show PR details
az repos pr show --id <ID> -o json | jq '{title: .title, description: .description}'

# Update PR title
az repos pr update --id <ID> --title "New title"

# Update PR description
az repos pr update --id <ID> --description "$(cat description.md)"

# Create PR
az repos pr create --title "Title" --description "$(cat description.md)" --source-branch <branch> --target-branch main
```

## PR Markdown Formatting

Azure DevOps markdown has specific formatting requirements.

### Work Item Links

Work item links (`#1234`) render with full metadata (title, status badge). For clean display:

**DO**: Put each link on its own line with blank lines between:
```markdown
## Related Work Items

#1234

#5678
```

**DON'T**: Put links on same line or use list format:
```markdown
#1234 #5678

- #1234
- #5678
```

## Work Item Hierarchy

Standard Azure DevOps hierarchy (top to bottom):
- **Initiative**: Product-level grouping
- **Epic**: Large initiative
- **Feature**: Major capability
- **PBI (Product Backlog Item)**: Deliverable work
- **Task**: Specific implementation step

## Work Item Linking

Work items are automatically linked when referenced in PR description with `#1234` syntax.
