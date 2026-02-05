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

# Remove parent relationship
az boards work-item relation remove --id <ID> --relation-type "parent" --target-id <PARENT_ID> -y
```

## Move Work Item Between Projects

Use REST API to move a work item to a different project. Update three fields together:
- `System.TeamProject` - target project name
- `System.AreaPath` - valid area path in target project
- `System.IterationPath` - valid iteration path in target project

```bash
az rest --method PATCH \
  --uri "https://dev.azure.com/{org}/_apis/wit/workitems/{id}?api-version=7.1" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798" \
  --headers "Content-Type=application/json-patch+json" \
  --body '[
    {"op": "add", "path": "/fields/System.TeamProject", "value": "{TargetProject}"},
    {"op": "add", "path": "/fields/System.AreaPath", "value": "{TargetProject}\\{Area}"},
    {"op": "add", "path": "/fields/System.IterationPath", "value": "{TargetProject}\\{Iteration}"}
  ]'
```

**Important**:
- Parent relationships are preserved if the parent is already in the target project
- Move parent items before children to maintain hierarchy
- The resource ID `499b84ac-1321-427f-aa17-267ca6975798` is required for Azure AD authentication

## Migration Workflow

When migrating work items between projects:

### 1. Create a Migration Area
Create a "Migration" area in the source project to track items being migrated. Move items here before processing.

### 2. Categorize Items
For each item, determine the action:
- **Move**: Item needs to be moved to target project (use REST API to update TeamProject/AreaPath/IterationPath)
- **Consolidate**: Equivalent item exists in target - mark as Removed with link and comment
- **Done**: Item was completed - leave as Done
- **Remove**: Item is obsolete/cancelled - mark as Removed

### 3. Consider Type Changes
Work item types may change during migration (case by case):
- Feature → PBI (if scope reduced)
- Feature → Epic (if scope increased)
- Epic → Feature (if scope reduced)

Evaluate each item's scope relative to the target project's structure.

### 4. Process Order - Bottom Up
Process children before parents (Task → PBI → Feature → Epic → Initiative). Parents can only be resolved when all children are resolved.

### 5. State Guidelines
- **Done**: Use when functionality is complete
- **Removed**: Use for migrated/consolidated/obsolete items (not Done - Done implies functionality is complete)

## Consolidating Work Items During Migration

When an equivalent work item already exists in the target project:

1. **Check descriptions** of both items. If both have descriptions, ask the user how to consolidate
2. **Copy description** from source to target if target has none
3. **Check `multilineFieldsFormat`** - if source has `"System.Description": "markdown"`, ensure destination also has markdown enabled (this is a UI toggle, not settable via API)
4. **Mark source as Removed** (not Done - Done implies functionality is complete)
5. **Add Related link** from source to target work item
6. **Add comment** explaining the consolidation with cross-project link

### Checking Markdown Format

Query the full work item to see the `multilineFieldsFormat` property:
```bash
az boards work-item show --id <ID> -o json | jq '{multilineFieldsFormat}'
```

If the source has `"System.Description": "markdown"` and the destination doesn't, the copied description will render as plain text. Enable markdown manually in the destination's description field UI.

**Note**: Once a field is set to markdown mode, you cannot switch back to HTML. The toggle is one-way.

**Markdown syntax reference**: https://learn.microsoft.com/en-us/azure/devops/project/wiki/markdown-guidance

### Comment Format for Cross-Project Links

Use HTML format with `data-vss-mention` attribute for proper rendering:

```bash
az rest --method POST \
  --uri "https://dev.azure.com/{org}/{project}/_apis/wit/workItems/{id}/comments?api-version=7.1-preview.4" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798" \
  --headers "Content-Type=application/json" \
  --body '{"text": "<div>Continued in <a href=\"https://dev.azure.com/{org}/{targetProject}/_workitems/edit/{targetId}/\" data-vss-mention=\"version:1.0\">#{targetId}</a> ({Title}) in {targetProject} project as part of work item migration.</div>"}'
```

**Note**: Plain text `#1234` does NOT auto-link for cross-project references. Must use full HTML anchor tag.

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

Azure DevOps hierarchy (top to bottom):
- **Epic**: Large initiative
- **Feature**: Major capability
- **PBI (Product Backlog Item)**: Deliverable work
- **Task**: Specific implementation step

**Note**: Custom portfolio backlog levels (e.g., Initiative) may exist above Epic. Query the project's process to find configured backlog levels.

## Work Item Linking

Work items are automatically linked when referenced in PR description with `#1234` syntax.
