# Backlog Column Configuration

Standard column layouts applied across all teams in a project.

## Standard Columns

**With Parent** (11 columns - Epics, Features, PBIs):
- ID, Parent, Title, State, Progress, Area Path, Iteration Path, Assigned To, Start Date, Target Date, Tags

**Without Parent** (10 columns - Initiative/top-level):
- ID, Title, State, Progress, Area Path, Iteration Path, Assigned To, Start Date, Target Date, Tags

## Field IDs and Column Option Keys Are Project-Specific

Start Date and Target Date field IDs, and the settings keys used for column options, vary per project/process. They cannot be hardcoded or assumed across projects. Both must be **discovered** per project.

**Known project data**:

| Project | Start Date ID | Target Date ID | Initiative Key | Epic Key | Feature Key | PBI Key |
|---------|--------------|----------------|----------------|----------|-------------|---------|
| Eagers | 23873555 | 23873544 | `Custom.c4680640-df9b-4845-a52d-63b3376ef825` | `Microsoft.EpicCategory` | `Microsoft.FeatureCategory` | `ProductBacklogColumnOptions` |
| CircuitBreaker | 37524899 | 37524888 | `Custom.3ac4ae14-92e5-46ce-a2c4-cbce4f23a58d` | `Microsoft.EpicCategory` | `Microsoft.FeatureCategory` | `ProductBacklogColumnOptions` |
| Flightrac | 46821680 | 46821669 | — | — | — | — |

`—` means not yet discovered for that project.

## Column API

Do NOT filter, transform, or pipe API output. Return full raw results.

```bash
# Get current column options for a team
~/.claude/skills/azure-devops/scripts/ado-rest.sh \
  --method GET \
  --path 'https://dev.azure.com/{org}/_apis/Settings/WebTeam/{team_id}/Entries/me/Agile/BacklogsHub/ColumnOptions'

# Set column options (PATCH merges settings keys)
~/.claude/skills/azure-devops/scripts/ado-rest.sh \
  --method PATCH \
  --path 'https://dev.azure.com/{org}/_apis/Settings/WebTeam/{team_id}/Entries/me' \
  --param 'api-version=7.1-preview' \
  -- --headers 'Content-Type=application/json' --body @/tmp/ado-columns-body.json

# Delete column options (reset to default)
~/.claude/skills/azure-devops/scripts/ado-rest.sh \
  --method DELETE \
  --path 'https://dev.azure.com/{org}/_apis/Settings/WebTeam/{team_id}/Entries/me/Agile/BacklogsHub/ColumnOptions/{category}' \
  --param 'api-version=7.1-preview'
```

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

