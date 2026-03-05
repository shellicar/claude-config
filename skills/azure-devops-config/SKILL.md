---
name: azure-devops-config
description: "Azure DevOps project structure, team configuration, and branch policies.\nTRIGGER when: discovering teams, configuring area paths, iteration paths, backlog visibility, column layouts, delivery plans, hierarchical team patterns, or managing branch protection policies.\nDO NOT TRIGGER when: creating/managing PRs, querying/updating work items, or running pipelines."
---

# Azure DevOps Configuration

**Scope:** CLI commands and REST API calls for configuring Azure DevOps project structure — teams, area/iteration paths, backlog visibility, delivery plans, column layouts, and branch policies. Work item audits live in `work-item-hygiene`. Organisational philosophy lives in `work-organisation`.

Project structure and team configuration. For work item CRUD see `azure-devops-boards`, for PRs see `azure-devops-repos`.

For org/project detection and the common resource ID, see `azure-devops`.

## Teams

```bash
# List teams in a project
az devops team list --project <Project> -o table

# List team iterations
az boards iteration team list --team <Team> --project <Project> -o table
```

**Team area assignments and team settings** (backlog visibility, bugs behaviour, working days):

```bash
# Team area path assignments
az boards area team list --team "<Team Name>" --project <Project> -o json

# Team settings - requires REST API
az rest --method GET \
  --uri 'https://dev.azure.com/{org}/{project}/{team_name}/_apis/work/teamsettings' \
  --resource '499b84ac-1321-427f-aa17-267ca6975798'
```

### Team Backlog Filtering

A team's backlog shows items matching **both** area path AND iteration path:
- Item must be in an area path the team owns (check `az boards area team list`)
- Item must be in an iteration the team has selected (check `work_list_team_iterations` via MCP or `az boards iteration team list`)

Teams can share area paths and differentiate by iteration, or share iterations and differentiate by area.

### Delivery Plans

Delivery plans visualise work across teams on a timeline. Items appear based on their team's backlog.

**Limitation — shared area paths**: When multiple teams own the same area paths, delivery plans show items in multiple team rows even if they belong to only one team's iterations. The [docs warn](https://learn.microsoft.com/en-us/azure/devops/boards/plans/review-team-plans?view=azure-devops#prerequisites): "Eliminate cross-team ownership of area paths to avoid undesirable edge cases."

**Workaround — tag-based field criteria**: Use separate delivery plans per team with tag filtering:
1. Tag work items with their team type (e.g., "Project" or "Support")
2. Create per-team delivery plans with field criteria: `Tags contains <TeamType>`

**Note**: Delivery plan field criteria does NOT support Iteration Path or Area Path — only fields like Tags, State, Work Item Type.

**Target Date overrides Iteration**: If a work item has both an Iteration (with dates) and a Target Date, the Target Date overrides the iteration end date on the plan. Avoid setting both — use Iteration for time-boxed work and clear Target Date, or use Start/Target dates for work spanning iterations.

**Same sprints for all levels**: Use the same sprints for Stories, Features, and Epics. Do not create separate sprints for Epics or other portfolio backlogs.

**Epics on delivery plans**: Plans require items to have an iteration with dates or explicit Start/Target dates. Ongoing Epics (capability groupings without time bounds) won't appear. Consider omitting Epics from delivery plans and using backlog hierarchy instead.

### Backlog Visibility Rules

See `work-organisation` skill for the philosophy behind backlog visibility (portfolio vs feature teams) and the hierarchical team pattern.

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

See `work-organisation` skill for the full hierarchical team pattern (portfolio vs area-based vs iteration-based teams, "Future" iteration).

**Trade-off for iteration-based teams**: Backlogs work correctly, but delivery plans need tag-based workaround (see Delivery Plans above).

**Reference**: [Configure hierarchical teams](https://learn.microsoft.com/en-us/azure/devops/boards/plans/configure-hierarchical-teams?view=azure-devops) | [Portfolio management](https://learn.microsoft.com/en-us/azure/devops/boards/plans/portfolio-management?view=azure-devops) | [Visibility across teams](https://learn.microsoft.com/en-us/azure/devops/boards/plans/visibility-across-teams?view=azure-devops) | [Agile culture](https://learn.microsoft.com/en-us/azure/devops/boards/plans/agile-culture?view=azure-devops)

## Uncovered Area Paths

Compare area path hierarchy against all teams' `teamfieldvalues` to find paths no team covers. For work item health checks (orphaned items, root area path items), see `work-item-hygiene`.

## Backlog Column Configuration

Apply standard column layouts across all teams. See [references/backlog-columns.md](references/backlog-columns.md) for column templates, known project data, and API examples.

### Workflow

1. **Determine org and project**: See `azure-devops` skill for detection. Print the org and project.
2. **Look up the project in the known project data table** in [references/backlog-columns.md](references/backlog-columns.md). Print a table of the project's field IDs and column option keys.
   - If the project is missing or has `—` for any values, **discover them**:
     1. Ask the user to manually set a column view in the UI for one team and one backlog level (e.g. set Title, Start Date, Target Date on the PBI backlog)
     2. Query that team's column options to learn the field IDs and settings keys
     3. Update the known project data table in `references/backlog-columns.md`
   - This is the ONLY step that requires manual user input.
3. **Query all teams** in the project. Print a table of team names and IDs.
4. **Query current settings for ALL teams** - for each team, GET column options using `--temp-file`:
      ```bash
      ~/.claude/skills/azure-devops/scripts/ado-rest.sh \
        --method GET \
        --path 'https://dev.azure.com/{org}/_apis/Settings/WebTeam/{team_id}/Entries/me/Agile/BacklogsHub/ColumnOptions' \
        --temp-file
      ```
      Read each temp file. Print a **summary table** of ALL teams showing: team name, which expected keys are present, and column count per key (or "not set").
5. **Show the change plan** - build the PATCH body using ONLY keys from the known project data table (Initiative Key → without-parent template, Epic/Feature/PBI Key → with-parent template). Use the project's field IDs for Start Date and Target Date. Save as `/tmp/ado-columns-body.json`.
      Print a **changes table** for ALL teams showing per team, per key:
      - Before column count (or "not set")
      - After column count
      - What's changing (e.g. "no change", "+Parent, +AreaPath", or "new: full template")
      The PATCH body is the same for all teams. This table shows what will change for each.
6. **Apply to all teams** - for each team, PATCH the column options:
      ```bash
      ~/.claude/skills/azure-devops/scripts/ado-rest.sh \
        --method PATCH \
        --path 'https://dev.azure.com/{org}/_apis/Settings/WebTeam/{team_id}/Entries/me' \
        --param 'api-version=7.1-preview' \
        -- --headers 'Content-Type=application/json' --body @/tmp/ado-columns-body.json
      ```
      Print: success or failure per team.
7. **Verify all teams** - for each team, GET column options again using `--temp-file`:
      ```bash
      ~/.claude/skills/azure-devops/scripts/ado-rest.sh \
        --method GET \
        --path 'https://dev.azure.com/{org}/_apis/Settings/WebTeam/{team_id}/Entries/me/Agile/BacklogsHub/ColumnOptions' \
        --temp-file
      ```
      Read each temp file. Print a **verification table** of ALL teams: team name, key, expected columns, actual columns, match (yes/no).

## Branch Policies

Query all branch policies for a project:

```bash
$ADO_REST --method GET \
  --path 'https://dev.azure.com/{org}/{project}/_apis/policy/configurations' \
  --param 'api-version=7.1'
```

Common policy types:
- `Require a merge strategy` — squash only, etc.
- `Comment requirements` — all comments must be resolved
- `Minimum number of reviewers` — required approvals
- `Required reviewers` — specific people must approve
- `Work item linking` — require linked work items

For **build validation policies**, see `azure-devops-pipelines`.

### Managing Policies

Use the REST API to create and update policies. Each policy type has a specific `type.id` — query existing policies first to find the type IDs for your org.

```bash
# Create a policy configuration
az rest --method POST \
  --url "https://dev.azure.com/{org}/{project}/_apis/policy/configurations?api-version=7.1" \
  --resource 499b84ac-1321-427f-aa17-267ca6975798 \
  --body '{
    "isEnabled": true,
    "isBlocking": true,
    "type": {"id": "<policy-type-id>"},
    "settings": {
      "minimumApproverCount": 1,
      "creatorVoteCounts": false,
      "scope": [{
        "repositoryId": "<repo-id>",
        "refName": "refs/heads/main",
        "matchKind": "exact"
      }]
    }
  }'

# Update a policy
az rest --method PUT \
  --url "https://dev.azure.com/{org}/{project}/_apis/policy/configurations/{policy-id}?api-version=7.1" \
  --resource 499b84ac-1321-427f-aa17-267ca6975798 \
  --body '{ ... }'
```

### Querying Repo ID

Policies require `repositoryId`. To find it:

```bash
$ADO_REST --method GET \
  --path 'https://dev.azure.com/{org}/{project}/_apis/git/repositories/{repo}' \
  --param 'api-version=7.1' | jq '.id'
```

### Branch Scoping

Policies scope to branches via the `settings.scope` array. Use the full ref (`refs/heads/main`).
