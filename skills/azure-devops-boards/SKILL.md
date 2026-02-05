---
name: azure-devops-boards
description: Work items, hierarchy, and migrations in Azure DevOps. Use when creating/querying/updating work items, planning features, managing epics/initiatives/areas/iterations, or migrating work items between projects.
---

# Azure DevOps Boards

Work items, hierarchy, and migrations. See also `azure-devops-repos` for PR workflows that link to work items.

## When Invoked

If the user invokes this skill, they likely want help with:
- **Planning** new features (where to put them in hierarchy, creating epics/features/PBIs)
- **Managing** high-level items (initiatives, epics, areas, iterations)
- **Creating** work items (tasks, PBIs, features, epics)
- **Querying** work items (finding, searching, listing)
- **Updating** work items (fields, state, relationships)
- **Organizing** work items (hierarchy, parents, iterations, areas)
- **Migrating** work items between projects

Ask what they need help with if not clear from context.

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

## Work Item Hierarchy

Azure DevOps hierarchy (top to bottom):
- **Epic**: Large initiative
- **Feature**: Major capability
- **PBI (Product Backlog Item)**: Deliverable work
- **Task**: Specific implementation step

**Note**: Custom portfolio backlog levels (e.g., Initiative) may exist above Epic. Query the project's process to find configured backlog levels.

## Iterations & Areas

```bash
# List project iterations
az boards iteration project list --project "<Project>" -o json | jq '.children[] | {name: .name, path: .path}'

# List child iterations (sprints)
az boards iteration project list --project "<Project>" --path "<Path>" --depth 2 -o json | jq '.children[] | {name: .name, path: .path, startDate: .attributes.startDate, finishDate: .attributes.finishDate}'

# List project area paths
az boards area project list --project "<Project>" -o json | jq '.children[] | {name: .name, path: .path}'
```

## Work Item Description Formatting

**IMPORTANT**: Work item descriptions MUST use HTML format, unless the field has been explicitly converted to markdown via the UI toggle.

### Check Format First

Query the work item to check if markdown is enabled:
```bash
az boards work-item show --id <ID> -o json | jq '{multilineFieldsFormat}'
```

- If `multilineFieldsFormat` is missing or doesn't include `"System.Description": "markdown"` → use HTML
- If `"System.Description": "markdown"` is present → use markdown

### HTML Format (Default)

- Wrap each line in `<div>` tags for proper line breaks
- Use `<div><br></div>` for blank lines between paragraphs
- Plain newlines in the CLI won't render as line breaks

**Example:**
```bash
az boards work-item update --id <ID> --fields "System.Description=<div>First line.</div><div><br></div><div>Second paragraph.</div><div>Third line.</div>"
```

### Markdown Format (When Enabled)

If the description field has been converted to markdown, use standard markdown syntax with newlines.

**Note**: Once a field is set to markdown mode, you cannot switch back to HTML. The toggle is one-way.

**Markdown syntax reference**: https://learn.microsoft.com/en-us/azure/devops/project/wiki/markdown-guidance

### Writing Style

Write descriptions like a professional speaking to a colleague, not notes or bullet points.

**DO**:
```
Handle js-joda types from the create buy a car schema.
Refactor to use record based mapping and fix the date formatting.
```

**DON'T**:
```
Schema now uses js-joda types.
mapToJson must handle them.
Refactored to give static errors when unmapped types are added.
```

The bad example reads like disconnected notes. The good example states what was done in clear sentences.

Say what it is without saying how you did it. Don't abstract things, don't dumb it down, don't try to sound smart.

### Task Titles

Task titles should describe the **effect** or **goal**, not the implementation:

**Good**: `Recalculate group status when facilitator licence changes`
**Bad**: `Add handleFacilitator to ProgramGroupViewProcessor`

Stakeholders read these titles - focus on what changes from their perspective, not what code you're writing.

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
