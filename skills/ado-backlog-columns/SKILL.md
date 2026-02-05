---
name: ado-backlog-columns
description: Configure consistent backlog column options across ADO teams. Use when standardizing backlog views, setting up team boards, or configuring column options.
---

# Azure DevOps Backlog Column Configuration

Configures consistent backlog column options across all teams in an Azure DevOps project.

## Usage

```
/ado-backlog-columns <org> <project>
```

Example:
```
/ado-backlog-columns myorg MyProject
```

## Standard Columns

The skill applies these columns to all backlogs:

**With Parent** (Epics, Features, PBIs):
- ID, Parent, Title, State, Progress, Area Path, Iteration Path, Assigned To, Start Date, Target Date, Tags

**Without Parent** (Initiative/top-level):
- ID, Title, State, Progress, Area Path, Iteration Path, Assigned To, Start Date, Target Date, Tags

## How It Works

1. **Discover teams** in the project
2. **Discover backlog categories** (Initiative, Epic, Feature, Requirement)
3. **Apply standard columns** to each team's backlog views

## API Details

### Get teams in a project
```bash
az rest --method GET \
  --uri "https://dev.azure.com/{org}/_apis/projects/{project}/teams?api-version=7.1" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798"
```

### Get current column options for a team
```bash
az rest --method GET \
  --uri "https://dev.azure.com/{org}/_apis/Settings/WebTeam/{team_id}/Entries/me/Agile/BacklogsHub/ColumnOptions" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798"
```

### Set column options for a team
```bash
az rest --method PATCH \
  --uri "https://dev.azure.com/{org}/_apis/Settings/WebTeam/{team_id}/Entries/me?api-version=7.1-preview" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798" \
  --headers "Content-Type=application/json" \
  --body '{"Agile/BacklogsHub/ColumnOptions/{category}":"[columns JSON]"}'
```

### Delete column options (reset to default)
```bash
az rest --method DELETE \
  --uri "https://dev.azure.com/{org}/_apis/Settings/WebTeam/{team_id}/Entries/me/Agile/BacklogsHub/ColumnOptions/{category}?api-version=7.1-preview" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798"
```

## Backlog Categories

**IMPORTANT**: The category keys stored in settings don't always match the API category names!

Common category keys:
- `Custom.c4680640-df9b-4845-a52d-63b3376ef825` - Initiative (custom top-level, no Parent)
- `Microsoft.EpicCategory` - Epics (with Parent)
- `Microsoft.FeatureCategory` - Features (with Parent)
- `ProductBacklogColumnOptions` - PBIs/Backlog items (with Parent) **NOT** `Microsoft.RequirementCategory`

Note: Categories may vary by project. Query existing column options to discover available categories. The PBI backlog uses `ProductBacklogColumnOptions` as the settings key, not the expected `Microsoft.RequirementCategory`.

## Field IDs Are Process-Specific

**IMPORTANT**: Field IDs for fields like Start Date and Target Date are **process-specific**, not universal.

Each process (including custom processes cloned from Scrum) gets its own field IDs assigned. You cannot use hardcoded IDs across different projects that use different processes.

**Known process field IDs**:

| Process | Start Date | Target Date |
|---------|------------|-------------|
| Eagers | 23873555 | 23873544 |
| Hope Ventures | 37524899 | 37524888 |

**To discover field IDs for a new project**:
1. Manually configure one backlog view in the UI with Start Date and Target Date columns
2. Query that team's column options via API
3. Extract the field IDs from the response

**Note**: Field IDs are embedded in server-side rendered page content, not exposed via a public REST API. The UI uses this SSR data when you add columns, which is why manual configuration followed by API query is required.

## Column JSON Templates

Replace `{START_DATE_ID}` and `{TARGET_DATE_ID}` with the process-specific field IDs.

### With Parent (11 columns)
```json
[
  {"id":-3,"name":"System.Id","text":"ID","fieldType":2,"width":100},
  {"id":-35,"name":"System.Parent","text":"Parent","fieldType":2,"width":100},
  {"name":"System.Title","text":"Title","fieldId":1,"canSortBy":true,"width":400,"isIdentity":false,"fieldType":1},
  {"name":"System.State","text":"State","fieldId":2,"canSortBy":true,"width":100,"isIdentity":false,"fieldType":1},
  {"width":100,"rollup":true,"rollupCalculation":{"type":0,"aggregation":1},"name":"System.Backlog.Rollup.ProgressBy.AllCompletedDescendants","text":"Progress by all Work Items"},
  {"id":-7,"name":"System.AreaPath","text":"Area Path","fieldType":8,"width":100},
  {"id":-105,"name":"System.IterationPath","text":"Iteration Path","fieldType":8,"width":100},
  {"id":24,"name":"System.AssignedTo","text":"Assigned To","fieldType":1,"width":100},
  {"id":{START_DATE_ID},"name":"Microsoft.VSTS.Scheduling.StartDate","text":"Start Date","fieldType":3,"width":100},
  {"id":{TARGET_DATE_ID},"name":"Microsoft.VSTS.Scheduling.TargetDate","text":"Target Date","fieldType":3,"width":100},
  {"id":80,"name":"System.Tags","text":"Tags","fieldType":5,"width":100}
]
```

### Without Parent (10 columns)
```json
[
  {"id":-3,"name":"System.Id","text":"ID","fieldType":2,"width":100},
  {"name":"System.Title","text":"Title","fieldId":1,"canSortBy":true,"width":400,"isIdentity":false,"fieldType":1},
  {"name":"System.State","text":"State","fieldId":2,"canSortBy":true,"width":100,"isIdentity":false,"fieldType":1},
  {"width":100,"rollup":true,"rollupCalculation":{"type":0,"aggregation":1},"name":"System.Backlog.Rollup.ProgressBy.AllCompletedDescendants","text":"Progress by all Work Items"},
  {"id":-7,"name":"System.AreaPath","text":"Area Path","fieldType":8,"width":100},
  {"id":-105,"name":"System.IterationPath","text":"Iteration Path","fieldType":8,"width":100},
  {"id":24,"name":"System.AssignedTo","text":"Assigned To","fieldType":1,"width":100},
  {"id":{START_DATE_ID},"name":"Microsoft.VSTS.Scheduling.StartDate","text":"Start Date","fieldType":3,"width":100},
  {"id":{TARGET_DATE_ID},"name":"Microsoft.VSTS.Scheduling.TargetDate","text":"Target Date","fieldType":3,"width":100},
  {"id":80,"name":"System.Tags","text":"Tags","fieldType":5,"width":100}
]
```

## Workflow

1. **Check for known field IDs**: Look up the project in the known process field IDs table above
2. **If unknown, discover field IDs**: Query existing column options from any team in the project. If Start Date/Target Date columns aren't configured yet, ask the user to add them to one backlog view in the UI, then query again to extract the IDs
3. **Query all teams** in the project
4. For each team, query existing column options to discover available categories
5. **Apply columns** using the discovered field IDs:
   - Initiative/top-level: No Parent column
   - Epics, Features, PBIs: Include Parent column
6. Verify by querying column options after applying

## Notes

- The resource ID `499b84ac-1321-427f-aa17-267ca6975798` is the Azure DevOps resource for AAD authentication
- Column options are per-user settings stored under `me/Agile/BacklogsHub/ColumnOptions`
- PATCH merges settings; use DELETE first to reset if needed
- The API requires the `-preview` suffix on the version for write operations
