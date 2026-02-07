# Backlog Column Configuration

Standard column layouts applied across all teams in a project.

## Standard Columns

**With Parent** (11 columns - Epics, Features, PBIs):
- ID, Parent, Title, State, Progress, Area Path, Iteration Path, Assigned To, Start Date, Target Date, Tags

**Without Parent** (10 columns - Initiative/top-level):
- ID, Title, State, Progress, Area Path, Iteration Path, Assigned To, Start Date, Target Date, Tags

## Field IDs Are Process-Specific

Start Date and Target Date field IDs vary per process. Cannot be hardcoded across projects.

**Known process field IDs**:

| Process | Start Date | Target Date |
|---------|------------|-------------|
| Eagers | 23873555 | 23873544 |
| Flightrac | 46821680 | 46821669 |
| Hope Ventures | 37524899 | 37524888 |

**To discover field IDs for a new project**:
1. Manually add Start Date and Target Date columns to one backlog view in the UI
2. Query that team's column options via API (see below)
3. Extract the field IDs from the response

## Backlog Category Keys

**IMPORTANT**: Category keys in settings don't always match API category names!

| Settings Key | Backlog Level |
|-------------|---------------|
| `Custom.{guid}` | Initiative (project-specific GUID) |
| `Microsoft.EpicCategory` | Epics |
| `Microsoft.FeatureCategory` | Features |
| `ProductBacklogColumnOptions` | PBIs (**NOT** `Microsoft.RequirementCategory`) |

Categories vary by project. Query existing column options to discover available categories.

## Column API

```bash
# Get current column options for a team
az rest --method GET \
  --uri 'https://dev.azure.com/{org}/_apis/Settings/WebTeam/{team_id}/Entries/me/Agile/BacklogsHub/ColumnOptions' \
  --resource '499b84ac-1321-427f-aa17-267ca6975798'

# Set column options (PATCH merges settings keys)
az rest --method PATCH \
  --uri 'https://dev.azure.com/{org}/_apis/Settings/WebTeam/{team_id}/Entries/me?api-version=7.1-preview' \
  --resource '499b84ac-1321-427f-aa17-267ca6975798' \
  --headers 'Content-Type=application/json' \
  --body @/tmp/ado-columns-body.json

# Delete column options (reset to default)
az rest --method DELETE \
  --uri 'https://dev.azure.com/{org}/_apis/Settings/WebTeam/{team_id}/Entries/me/Agile/BacklogsHub/ColumnOptions/{category}?api-version=7.1-preview' \
  --resource '499b84ac-1321-427f-aa17-267ca6975798'
```

**Note**: `api-version` is omitted from GET URIs (Azure DevOps defaults to latest). Write operations (PATCH/DELETE) that require `-preview` suffix keep it as a single query param. Avoid `&` in URIs as Claude Code's permission matcher treats it as a shell operator and will prompt for approval.

**Note**: Column options are per-user settings stored under `me/`.

## Column JSON Templates

Replace `{START_DATE_ID}` and `{TARGET_DATE_ID}` with process-specific field IDs.

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

1. **Determine org and project**: See `azure-devops` skill for detection.
2. **Check for known field IDs**: Look up in table above.
3. **If unknown**: Query existing column options from any team. If Start Date/Target Date not configured, ask user to add them in UI first, then query again.
4. **Query all teams** in the project.
5. **Query column options** from one team to discover available category keys.
6. **Build PATCH body** combining all categories into one JSON object (category keys as keys, column JSON arrays as string values):
   ```json
   {
     "Agile/BacklogsHub/ColumnOptions/{initiative-category}": "<without-parent columns as JSON string>",
     "Agile/BacklogsHub/ColumnOptions/Microsoft.EpicCategory": "<with-parent columns as JSON string>",
     "Agile/BacklogsHub/ColumnOptions/Microsoft.FeatureCategory": "<with-parent columns as JSON string>",
     "Agile/BacklogsHub/ColumnOptions/ProductBacklogColumnOptions": "<with-parent columns as JSON string>"
   }
   ```
   Save as `/tmp/ado-columns-body.json`.
7. **Apply** to each team using `az rest --method PATCH --body @/tmp/ado-columns-body.json`.
8. **Verify** by querying column options after applying.
