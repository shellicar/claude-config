---
name: azure-devops-repos
description: PRs, merge workflows, and branch policies in Azure DevOps. Use when creating/managing PRs, setting auto-complete, linking work items to PRs, configuring merge commit messages, or managing branch protection policies.
---

# Azure DevOps Repos

**Scope:** CLI commands for Azure DevOps PRs, auto-complete, work item linking, merge commit messages, and branch policies.

Pull requests, work item linking, and merge workflows. See also `azure-devops-boards` for work item hierarchy and formatting.

## When Invoked

If the user invokes this skill, they likely want help with:
- **Creating** PRs with proper descriptions and work item links
- **Managing** PRs (updating, reviewing, completing)
- **Auto-complete** setup with merge commit messages
- **Branch** operations and policies

Ask what they need help with if not clear from context.

## Pull Requests

All PR operations use `az rest` (via `ado-rest.sh`) instead of `az repos`. The `az devops` extension has unreliable authentication — `az rest` with `--resource` uses the standard `az login` AAD token directly.

```bash
ADO_REST=~/.claude/skills/azure-devops/scripts/ado-rest.sh
BASE="https://dev.azure.com/{org}/{project}/_apis/git/repositories/{repo}"

# List active PRs
$ADO_REST --method GET \
  --path "$BASE/pullrequests" \
  --param 'searchCriteria.status=active' \
  --param 'api-version=7.1'

# Show PR details
$ADO_REST --method GET \
  --path "$BASE/pullrequests/{id}" \
  --param 'api-version=7.1'

# Create PR
az rest --method POST \
  --url "$BASE/pullrequests?api-version=7.1" \
  --resource 499b84ac-1321-427f-aa17-267ca6975798 \
  --body '{
    "sourceRefName": "refs/heads/<branch>",
    "targetRefName": "refs/heads/main",
    "title": "Title",
    "description": "Description"
  }'

# Update PR (title, description, auto-complete, merge options)
az rest --method PATCH \
  --url "$BASE/pullrequests/{id}?api-version=7.1" \
  --resource 499b84ac-1321-427f-aa17-267ca6975798 \
  --body '{
    "autoCompleteSetBy": {"id": "<user-id>"},
    "completionOptions": {
      "mergeStrategy": "squash",
      "deleteSourceBranch": true,
      "transitionWorkItems": true,
      "mergeCommitMessage": "Merged PR {id}: {title}\n\n{description}"
    }
  }'

# Link work items to PR
az rest --method PATCH \
  --url "https://dev.azure.com/{org}/{project}/_apis/wit/workitems/{wi-id}?api-version=7.1" \
  --resource 499b84ac-1321-427f-aa17-267ca6975798 \
  --headers 'Content-Type=application/json-patch+json' \
  --body '[{
    "op": "add",
    "path": "/relations/-",
    "value": {
      "rel": "ArtifactLink",
      "url": "vstfs:///Git/PullRequestId/{project-id}%2F{repo-id}%2F{pr-id}",
      "attributes": {"name": "Pull Request"}
    }
  }]'
```

## Linking Work Items to PRs

- **PBI**: Link in the PR description using `#1234` syntax (auto-linked by Azure DevOps)
- **Tasks**: Link via REST API (see work item linking example above)

This keeps the description clean while still associating all related work.

## PR Completion Workflow

Follow this exact workflow when completing a PR via CLI:

1. **Create PR** with PBI linked in description
2. **Link Task** via `az repos pr work-item add --id <PR_ID> --work-items <TASK_ID>`
3. **Preview merge message**: `pr-merge-message.sh --org <org> --id <PR_ID> --show`
4. **Set auto-complete with merge message**:
   ```bash
   pr-merge-message.sh --org <org> --id <PR_ID> --set-auto-complete
   ```

The `--set-auto-complete` option sets auto-complete with all required flags (`--squash true`, `--transition-work-items true`) AND the merge commit message in a single command, then validates it was set correctly.

**Note**: Setting auto-complete via CLI without `--merge-commit-message` clears any existing message. The script handles this by setting both together.

## Merge Commit Message Script

Use `~/.claude/skills/azure-devops-repos/scripts/pr-merge-message.sh` to manage merge commit messages:

```bash
# Show what the merge commit message should be
pr-merge-message.sh --org <ORG> --id <PR_ID> --show

# Set auto-complete with squash, transition-work-items, AND merge commit message (recommended)
pr-merge-message.sh --org <ORG> --id <PR_ID> --set-auto-complete

# Validate current merge commit message matches expected format
pr-merge-message.sh --org <ORG> --id <PR_ID> --validate

# Set only the merge commit message (without auto-complete flags)
pr-merge-message.sh --org <ORG> --id <PR_ID> --set
```

Expected format:
```
Merged PR {id}: {title}

{description}
```

**Note**: The repo might be in a different project than the work items. Cross-project linking still works.

## PR Markdown Formatting

Azure DevOps markdown has specific formatting requirements.

### Work Item Links

Work item links (`#1234`) render with full metadata (title, status badge). For clean display:

**DO**: Put each link on its own line with blank lines between:
```markdown
## Related Work Items

#1234

#5678
```

**DON'T**: Put links on same line or use list format:
```markdown
#1234 #5678

- #1234
- #5678
```

## Work Item Linking

Work items are automatically linked when referenced in PR description with `#1234` syntax.

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
