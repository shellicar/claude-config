---
name: azure-devops-mcp
description: Azure DevOps MCP server tool reference, installation, and gotchas. Use when interacting with Azure DevOps APIs (work items, PRs, pipelines, wiki, test plans, search). Prefer MCP tools over `az` CLI. Also loaded by other azure-devops skills for API operations.
user-invocable: false
---

# Azure DevOps MCP

MCP server providing typed tool access to Azure DevOps APIs. When available, prefer MCP tools over `az` CLI commands for all API operations.

GitHub: https://github.com/microsoft/azure-devops-mcp

Package: `@azure-devops/mcp`

## Detection

Check if the `ado` MCP is available:

```
ToolSearch query: "+ado"
```

If `mcp__ado__*` tools appear in results, the MCP is installed and available. If not, see [Installation](#installation).

## Installation

Install for the current user (pin to a specific version):

```bash
# Check latest version
npm view @azure-devops/mcp dist-tags --json

# Install with pinned version
claude mcp add ado -- npx -y @azure-devops/mcp@<version> <org-name>
```

Replace `<org-name>` with the Azure DevOps organisation name (e.g., `eagersautomotive`).

This adds the server to `~/.claude.json` under `mcpServers`.

**After installing**: Claude CLI must be restarted for the MCP server to become available. Resuming an existing session after restart is sufficient — a brand new session is not required.

**Prerequisites**:
- Node.js / npm (for `npx`)
- Azure DevOps PAT or active `az` CLI login for authentication

## Using MCP Tools

MCP tools are deferred — they must be loaded via `ToolSearch` before first use in a session:

```
ToolSearch query: "select:mcp__ado__wit_get_work_item"
```

Or load multiple tools by category:

```
ToolSearch query: "+ado work item"
ToolSearch query: "+ado pull request"
ToolSearch query: "+ado pipeline"
```

Once loaded, call them directly as tool calls with typed JSON parameters.

## Tool Categories

### Core

| Tool | Use for |
|------|---------|
| `core_list_projects` | List projects in the org |
| `core_list_project_teams` | List teams in a project |
| `core_get_identity_ids` | Look up user/team identity IDs by name or email |

### Work Items

| Tool | Use for |
|------|---------|
| `wit_get_work_item` | Get a single work item (use `expand: "relations"` for children/parents) |
| `wit_get_work_items_batch_by_ids` | Get multiple work items at once |
| `wit_create_work_item` | Create a work item (fields use `System.Title`, `System.AreaPath`, etc.) |
| `wit_update_work_item` | Update fields on a work item |
| `wit_update_work_items_batch` | Batch update multiple work items |
| `wit_my_work_items` | Get work items assigned to the current user |
| `wit_get_work_items_for_iteration` | Get all work items in an iteration |
| `wit_list_backlog_work_items` | List backlog items for a team |
| `wit_list_backlogs` | List available backlogs for a team |
| `wit_get_query` | Get a saved query definition |
| `wit_get_query_results_by_id` | Execute a saved query |
| `wit_get_work_item_type` | Get work item type definition (fields, rules) |
| `wit_list_work_item_comments` | List comments on a work item |
| `wit_add_work_item_comment` | Add a comment to a work item |
| `wit_list_work_item_revisions` | List revision history |
| `wit_add_child_work_items` | Add child work items |
| `wit_work_items_link` | Link work items together (parent, child, related, predecessor, etc.) |
| `wit_work_item_unlink` | Remove links between work items |
| `wit_link_work_item_to_pull_request` | Link a work item to a PR |
| `wit_add_artifact_link` | Link work items to branches, builds, commits, PRs |

### Repos & PRs

| Tool | Use for |
|------|---------|
| `repo_get_repo_by_name_or_id` | Get repository details (need repo ID for most other calls) |
| `repo_list_repos_by_project` | List all repos in a project |
| `repo_create_pull_request` | Create a PR (can link work items at creation) |
| `repo_update_pull_request` | Update PR (title, description, auto-complete, merge strategy, labels) |
| `repo_get_pull_request_by_id` | Get PR details |
| `repo_list_pull_requests_by_repo_or_project` | List PRs |
| `repo_list_pull_requests_by_commits` | Find PRs associated with specific commits |
| `repo_update_pull_request_reviewers` | Add or remove reviewers |
| `repo_list_pull_request_threads` | List PR comment threads (filterable by status, author) |
| `repo_list_pull_request_thread_comments` | List comments in a thread |
| `repo_create_pull_request_thread` | Create a new comment thread on a PR |
| `repo_reply_to_comment` | Reply to an existing comment |
| `repo_update_pull_request_thread` | Update thread status (resolve, etc.) |
| `repo_create_branch` | Create a branch |
| `repo_get_branch_by_name` | Get branch details |
| `repo_list_branches_by_repo` | List all branches |
| `repo_list_my_branches_by_repo` | List branches created by current user |
| `repo_search_commits` | Search commits (by text, author, date range, work items) |

### Pipelines & Builds

| Tool | Use for |
|------|---------|
| `pipelines_run_pipeline` | Queue a pipeline run |
| `pipelines_get_run` | Get details of a pipeline run |
| `pipelines_list_runs` | List pipeline runs |
| `pipelines_create_pipeline` | Create a new pipeline |
| `pipelines_get_builds` | List builds |
| `pipelines_get_build_status` | Get build status |
| `pipelines_get_build_definitions` | List build/pipeline definitions |
| `pipelines_get_build_definition_revisions` | Get revision history of a definition |
| `pipelines_get_build_log` | Get all logs for a build |
| `pipelines_get_build_log_by_id` | Get a specific log (supports line ranges) |
| `pipelines_get_build_changes` | Get commits included in a build |
| `pipelines_update_build_stage` | Retry or cancel a build stage |

### Iterations & Capacity

| Tool | Use for |
|------|---------|
| `work_list_team_iterations` | List iterations assigned to a team |
| `work_list_iterations` | List all iterations in a project |
| `work_create_iterations` | Create new iterations |
| `work_assign_iterations` | Assign iterations to a team |
| `work_get_team_capacity` | Get team member capacity for an iteration |
| `work_get_iteration_capacities` | Get capacity across all teams for an iteration |
| `work_update_team_capacity` | Update a team member's capacity |

### Wiki

| Tool | Use for |
|------|---------|
| `wiki_list_wikis` | List wikis in a project |
| `wiki_get_wiki` | Get wiki details |
| `wiki_list_pages` | List pages in a wiki |
| `wiki_get_page` | Get page metadata (not content) |
| `wiki_get_page_content` | Get page content |
| `wiki_create_or_update_page` | Create or update a wiki page |

### Search

| Tool | Use for |
|------|---------|
| `search_code` | Search code across repos |
| `search_workitem` | Search work items by text |
| `search_wiki` | Search wiki content |

### Advanced Security

| Tool | Use for |
|------|---------|
| `advsec_get_alerts` | Get security alerts (dependency, secret, code) |
| `advsec_get_alert_details` | Get details for a specific alert |

### Test Plans

| Tool | Use for |
|------|---------|
| `testplan_list_test_plans` | List test plans |
| `testplan_create_test_plan` | Create a test plan |
| `testplan_list_test_suites` | List test suites |
| `testplan_create_test_suite` | Create a test suite |
| `testplan_list_test_cases` | List test cases |
| `testplan_create_test_case` | Create a test case |
| `testplan_add_test_cases_to_suite` | Add test cases to a suite |
| `testplan_update_test_case_steps` | Update test case steps |
| `testplan_show_test_results_from_build_id` | Get test results from a build |

## MCP Gotchas

### Repository IDs

Most repo/PR tools require `repositoryId` (a GUID), not the repo name. Get it first:

```
mcp__ado__repo_get_repo_by_name_or_id(repositoryId: "MyRepo", project: "MyProject")
```

Then use the `id` from the response in subsequent calls.

### Work Item Fields

Field names use the full reference name:
- `System.Title`, `System.State`, `System.AreaPath`, `System.IterationPath`
- `System.AssignedTo`, `System.Description`, `System.WorkItemType`
- `Microsoft.VSTS.Common.BacklogPriority`
- `Microsoft.VSTS.Scheduling.StartDate`, `Microsoft.VSTS.Scheduling.TargetDate`

### Branch Ref Names

PR tools expect full ref names: `refs/heads/main`, not just `main`.

### PR Auto-Complete

Use `repo_update_pull_request` with `autoComplete: true` and `mergeStrategy` to set auto-complete. Available strategies: `NoFastForward`, `Squash`, `Rebase`, `RebaseMerge`.

### Work Item Linking

`wit_work_items_link` supports these link types: `parent`, `child`, `duplicate`, `duplicate of`, `related`, `successor`, `predecessor`, `tested by`, `tests`, `affects`, `affected by`.

### Expand Relations

To see parent/child relationships on a work item, use `expand: "relations"` on `wit_get_work_item`.

## Version Management

The MCP server is configured in `~/.claude.json` under `mcpServers.ado`.

**Check the pinned version**:
```bash
jq -r '.mcpServers.ado.args[] | select(startswith("@azure-devops/mcp"))' ~/.claude.json
```

**Check the latest available version**:
```bash
npm view @azure-devops/mcp dist-tags --json
```

**Update the pinned version**: Edit `~/.claude.json` and update the version in the args array (e.g., `@azure-devops/mcp@2.4.0`). Claude CLI must be restarted after changes.

## Fallback: az CLI

If the MCP is not available, fall back to `az` CLI commands. See `azure-devops` skill and its sub-skills for CLI usage patterns and the `ado-rest.sh` wrapper script.

## What MCP Does NOT Cover

These still require `az` CLI, `az rest`, or custom scripts:

- **WIQL queries**: MCP can execute saved queries (`wit_get_query_results_by_id`) but cannot run ad-hoc WIQL. Use `az boards query --wiql` for custom queries.
- **Branch policies**: No MCP tools for policy CRUD. Use `az repos policy` commands.
- **Area path / iteration path CRUD**: No MCP tools for creating/deleting area or iteration paths. Use `az boards area/iteration project` commands.
- **Team settings**: No MCP tools for backlog visibility, bugs behaviour, or working days. Use `az rest` with the team settings API.
- **Backlog column configuration**: Uses the undocumented Settings API. See `azure-devops-org` skill.
- **Merge commit messages**: MCP `update_pull_request` doesn't support setting the merge commit message directly. Use `pr-merge-message.sh` from `azure-devops-repos` skill.
- **Pipeline policy sync**: Comparing YAML triggers with build validation policies. Use `pipeline-policy-sync.sh` from `azure-devops-pipelines` skill.
