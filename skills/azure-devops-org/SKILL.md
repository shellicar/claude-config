---
name: azure-devops-org
description: Azure DevOps project organisation and team configuration. Use when discovering project structure (teams, area paths, iteration paths), configuring team settings (backlog visibility, area assignments), applying standard backlog column options, auditing for orphaned work items, or setting up hierarchical team patterns (portfolio teams vs feature teams).
---

# Azure DevOps Organisation

Project structure, team configuration, and organisational health. For work item CRUD see `azure-devops-boards`, for PRs see `azure-devops-repos`.

For org/project detection and the common resource ID, see `azure-devops`.

## Teams

```bash
# List teams
az rest --method GET \
  --uri 'https://dev.azure.com/{org}/_apis/projects/{project}/teams' \
  --resource '499b84ac-1321-427f-aa17-267ca6975798'

# Team settings (backlog visibility, bugs behaviour, working days)
az rest --method GET \
  --uri 'https://dev.azure.com/{org}/{project}/{team_name}/_apis/work/teamsettings' \
  --resource '499b84ac-1321-427f-aa17-267ca6975798'

# Team area path assignments
az rest --method GET \
  --uri 'https://dev.azure.com/{org}/{project}/{team_name}/_apis/work/teamsettings/teamfieldvalues' \
  --resource '499b84ac-1321-427f-aa17-267ca6975798'

# Team iteration assignments
az rest --method GET \
  --uri 'https://dev.azure.com/{org}/{project}/{team_name}/_apis/work/teamsettings/iterations' \
  --resource '499b84ac-1321-427f-aa17-267ca6975798'
```

### Backlog Visibility

The `backlogVisibilities` field controls which backlog levels a team sees. Common categories:

| Key | Level |
|-----|-------|
| `Custom.{guid}` | Initiative (custom, project-specific GUID) |
| `Microsoft.EpicCategory` | Epics |
| `Microsoft.FeatureCategory` | Features |
| `Microsoft.RequirementCategory` | PBIs |

**IMPORTANT**: PATCH on `backlogVisibilities` **replaces** the entire object, not merges. Always send ALL categories:

```bash
az rest --method PATCH \
  --uri 'https://dev.azure.com/{org}/{project}/{team_name}/_apis/work/teamsettings' \
  --resource '499b84ac-1321-427f-aa17-267ca6975798' \
  --headers 'Content-Type=application/json' \
  --body '{"backlogVisibilities":{"Custom.{guid}":true,"Microsoft.EpicCategory":true,"Microsoft.FeatureCategory":true,"Microsoft.RequirementCategory":true}}'
```

## Area Paths & Iteration Paths

```bash
# Full area path hierarchy
az rest --method GET \
  --uri 'https://dev.azure.com/{org}/{project}/_apis/wit/classificationNodes/Areas?$depth=10' \
  --resource '499b84ac-1321-427f-aa17-267ca6975798'

# Full iteration hierarchy
az rest --method GET \
  --uri 'https://dev.azure.com/{org}/{project}/_apis/wit/classificationNodes/Iterations?$depth=10' \
  --resource '499b84ac-1321-427f-aa17-267ca6975798'
```

## Hierarchical Team Pattern

**Portfolio/Management team**:
- All backlog levels enabled (for visibility across the whole project)
- All area paths with `includeChildren: true`
- Sees everything, manages at Initiative/Epic level, uses lower levels for visibility

**Feature teams**:
- Features + PBIs only (Initiative/Epic disabled)
- Own area path only with `includeChildren: true`
- Focused on their delivery scope

**"Future" area** (optional):
- Parking area for ideas not yet assigned to a team
- Covered by Portfolio team for visibility
- Items get moved to a feature team's area once they're understood

## Audit / Health Checks

**Note**: Use `-o json` for audit queries. The `-o table` format drops fields from `az boards query` results.

### Orphaned work items (no parent, excluding top-level)
Top-level items (Initiatives) are expected to have no parent. Exclude them and Tasks:
```bash
az boards query --wiql "SELECT [System.Id], [System.Title], [System.WorkItemType], [System.AreaPath] \
  FROM WorkItems WHERE [System.Parent] = '' AND [System.State] <> 'Removed' \
  AND [System.State] <> 'Done' AND [System.WorkItemType] <> 'Task' \
  AND [System.WorkItemType] <> 'Initiative' \
  ORDER BY [System.WorkItemType]" --project {project} --org https://dev.azure.com/{org} -o json
```

### Items on root area path (not assigned to a sub-area)
These items are likely from before a team hierarchy was set up and may not be visible on any feature team's backlog:
```bash
az boards query --wiql "SELECT [System.Id], [System.Title], [System.WorkItemType] \
  FROM WorkItems WHERE [System.AreaPath] = '{project}' \
  AND [System.State] <> 'Removed' AND [System.State] <> 'Done' \
  ORDER BY [System.WorkItemType]" --project {project} --org https://dev.azure.com/{org} -o json
```

### Uncovered area paths
Compare area path hierarchy against all teams' `teamfieldvalues` to find paths no team covers.

## Backlog Column Configuration

Apply standard column layouts across all teams. See [references/backlog-columns.md](references/backlog-columns.md) for column templates, field IDs, and the step-by-step workflow.
