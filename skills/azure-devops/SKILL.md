---
name: azure-devops
description: Shared Azure DevOps foundation. Auto-detects org/project from git remote and routes to sub-skills. Use when working with any Azure DevOps project, or when unsure which sub-skill to use. Also loaded by sub-skills for org/project detection.
---

# Azure DevOps

Shared foundation for all Azure DevOps skills. Provides org/project detection and routing to sub-skills.

## Org/Project Detection

When org/project are not provided, detect from git remote:

```bash
git remote -v
```

Parse the remote with `dev.azure.com` in the URL:
- `https://{org}@dev.azure.com/{org}/{project}/_git/{repo}` -> org, project
- `git@ssh.dev.azure.com:v3/{org}/{project}/{repo}` -> org, project

If no Azure DevOps remote found, use `AskUserQuestion` to ask for org and project. **Always confirm** with `AskUserQuestion` before making changes.

## REST API Wrapper

Use `scripts/ado-rest.sh` for all `az rest` calls. It handles authentication (resource ID), URL construction, and input sanitisation:

```bash
# Simple GET (no query params)
~/.claude/skills/azure-devops/scripts/ado-rest.sh \
  --path 'https://dev.azure.com/{org}/_apis/projects/{project}/teams'

# GET with query params (avoids & permission issues)
~/.claude/skills/azure-devops/scripts/ado-rest.sh \
  --path 'https://dev.azure.com/{org}/{project}/_apis/wit/classificationNodes/Areas' \
  --param '$depth=10'

# Non-GET with extra az rest args
~/.claude/skills/azure-devops/scripts/ado-rest.sh \
  --method PATCH \
  --path 'https://dev.azure.com/{org}/{project}/{team}/_apis/work/teamsettings' \
  -- --headers 'Content-Type=application/json' --body '{"backlogVisibilities":{...}}'
```

**Why**: Claude Code's permission matcher treats `&` as a shell operator, prompting for approval even inside quoted strings. The script constructs multi-param URLs internally, bypassing this limitation.

For simple single-param URLs, direct `az rest` calls still work fine.

## Sub-Skills

| Skill | Azure DevOps Section | Use For |
|-------|---------------------|---------|
| `azure-devops-org` | Organisation | Teams, area paths, iterations, backlog visibility, column config, audits |
| `azure-devops-boards` | Boards | Work items, hierarchy, migrations, descriptions |
| `azure-devops-repos` | Repos | PRs, work item linking, merge workflows |
| `azure-devops-pipelines` | Pipelines | Pipeline runs, configuration, triggers, policies |
