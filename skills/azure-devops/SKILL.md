---
name: azure-devops
description: Shared Azure DevOps foundation. Auto-detects org/project from git remote and routes to sub-skills. Use when working with any Azure DevOps project, or when unsure which sub-skill to use. Also loaded by sub-skills for org/project detection.
---

# Azure DevOps

Shared foundation for all Azure DevOps skills. Provides org/project detection, API layer selection, and routing to sub-skills.

## API Layer: MCP vs CLI

**Prefer MCP when available.** Check for the `ado` MCP server first — see `azure-devops-mcp` skill for detection, installation, and tool reference.

- **MCP available**: Use `mcp__ado__*` tools for all API operations. Typed parameters, no shell permissions needed.
- **MCP not available**: Fall back to `az` CLI and `ado-rest.sh` (see [CLI Fallback](#cli-fallback) below).

## Org/Project Detection

When org/project are not provided, detect from git remote:

```bash
git remote -v
```

Parse the remote with `dev.azure.com` in the URL:
- `https://{org}@dev.azure.com/{org}/{project}/_git/{repo}` -> org, project
- `git@ssh.dev.azure.com:v3/{org}/{project}/{repo}` -> org, project

If no Azure DevOps remote found, use `AskUserQuestion` to ask for org and project. **Always confirm** with `AskUserQuestion` before making changes.

## Sub-Skills

| Skill | Section | Use For |
|-------|---------|---------|
| `azure-devops-mcp` | API layer | MCP tool reference, installation, gotchas |
| `azure-devops-org` | Organisation | Teams, area paths, iterations, backlog visibility, column config, audits |
| `azure-devops-boards` | Boards | Work items, hierarchy, migrations, descriptions |
| `azure-devops-repos` | Repos | PRs, work item linking, merge workflows |
| `azure-devops-pipelines` | Pipelines | Pipeline runs, configuration, triggers, policies |

## CLI Fallback

When MCP is not available, use `scripts/ado-rest.sh` for `az rest` calls. It handles authentication (resource ID), URL construction, and input sanitisation:

```bash
# Simple GET (no query params)
~/.claude/skills/azure-devops/scripts/ado-rest.sh \
  --method GET \
  --path 'https://dev.azure.com/{org}/_apis/projects/{project}/teams'

# GET with query params (avoids & permission issues)
~/.claude/skills/azure-devops/scripts/ado-rest.sh \
  --method GET \
  --path 'https://dev.azure.com/{org}/{project}/_apis/wit/classificationNodes/Areas' \
  --param '$depth=10'

# GET column options for a team (confirm existing backlog column config)
~/.claude/skills/azure-devops/scripts/ado-rest.sh \
  --method GET \
  --path 'https://dev.azure.com/{org}/_apis/Settings/WebTeam/{team_id}/Entries/me/Agile/BacklogsHub/ColumnOptions'

# Non-GET with extra az rest args
~/.claude/skills/azure-devops/scripts/ado-rest.sh \
  --method PATCH \
  --path 'https://dev.azure.com/{org}/{project}/{team}/_apis/work/teamsettings' \
  -- --headers 'Content-Type=application/json' --body '{"backlogVisibilities":{...}}'
```

**Why**: Claude Code's permission matcher treats `&` as a shell operator, prompting for approval even inside quoted strings. The script constructs multi-param URLs internally, bypassing this limitation.
