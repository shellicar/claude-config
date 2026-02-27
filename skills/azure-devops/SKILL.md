---
name: azure-devops
description: Shared Azure DevOps foundation. Auto-detects org/project from git remote and routes to sub-skills. Use when working with any Azure DevOps project, or when unsure which sub-skill to use. Also loaded by sub-skills for org/project detection and REST API wrapper.
---

# Azure DevOps

**Scope:** Org/project detection from git remotes and the shared REST API wrapper. Sub-skill routing, not sub-skill content.

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

## Sub-Skills

| Skill | Section | Use For |
|-------|---------|---------|
| `azure-devops-org` | Organisation | Teams, area paths, iterations, backlog visibility, column config, audits |
| `azure-devops-boards` | Boards | Work items, hierarchy, migrations, descriptions |
| `azure-devops-repos` | Repos | PRs, work item linking, merge workflows |
| `azure-devops-pipelines` | Pipelines | Pipeline runs, configuration, triggers, policies |

## REST API Wrapper

Use `scripts/ado-rest.sh` for all `az rest` calls. It handles authentication (resource ID), URL construction, and input sanitisation:

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

For simple single-param URLs, direct `az rest` calls still work fine.

## Troubleshooting: Token Expiry

When `az` CLI commands fail unexpectedly with auth errors (e.g. "not authorized", 401, 403), check token validity:

```bash
az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "expiresOn" -o tsv
```

The resource ID `499b84ac-1321-427f-aa17-267ca6975798` is the Azure DevOps service principal. This checks the actual DevOps token, not just the general Azure session.

- **Token returned with future expiry**: Token is probably valid — but see caveat below.
- **Error or past expiry**: Token has expired. The Supreme Commander needs to run `az login` to refresh.

**Caveat**: Company policies (e.g. Conditional Access, session lifetime policies) may revoke or expire tokens before the `expiresOn` time — for example, every 24 hours. If commands fail with auth errors but the token appears valid, the session may have been invalidated by policy. Suggest `az login` regardless.

**Why `get-access-token`**: This is a POST that actively requests a token — if the session is expired, it will fail or return a past expiry. `az account show` will still succeed with an expired token because it only reads local account config. Always use `get-access-token` with the DevOps resource ID for a definitive check.

**Common symptom**: `az repos pr show` fails while `az rest` (with explicit `--resource`) may still work, because they use different token refresh paths. If one fails, check the token and suggest `az login`.
