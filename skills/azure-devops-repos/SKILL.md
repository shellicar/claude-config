---
name: azure-devops-repos
description: "PRs and merge workflows in Azure DevOps.\nTRIGGER when: creating PRs, updating PRs, setting auto-complete, linking work items to PRs, or configuring merge commit messages.\nDO NOT TRIGGER when: configuring branch policies, querying project structure, formatting work item descriptions, or non-PR git operations."
---

# Azure DevOps Repos

**Scope:** CLI commands for Azure DevOps PRs — CRUD, auto-complete, work item linking, merge commit messages, and PR markdown formatting. Branch policies live in `azure-devops-config`.

Pull requests, work item linking, and merge workflows. See also `azure-devops-boards` for work item hierarchy and formatting.

## When Invoked

If the user invokes this skill, they likely want help with:
- **Creating** PRs with proper descriptions and work item links
- **Managing** PRs (updating, reviewing, completing)
- **Auto-complete** setup with merge commit messages

For branch policies, see `azure-devops-config`.

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
3. **Preview merge message**:
   ```bash
   echo '{"org":"<ORG>","id":"<PR_ID>","mode":"show"}' | pr-merge-message.sh
   ```
4. **Set auto-complete with merge message**:
   ```bash
   echo '{"org":"<ORG>","id":"<PR_ID>","mode":"set-auto-complete"}' | pr-merge-message.sh
   ```

The `set-auto-complete` mode sets auto-complete with all required flags (`--squash true`, `--transition-work-items true`) AND the merge commit message in a single command, then validates it was set correctly.

**Note**: Setting auto-complete via CLI without `--merge-commit-message` clears any existing message. The script handles this by setting both together.

## Merge Commit Message Script

Use `~/.claude/skills/azure-devops-repos/scripts/pr-merge-message.sh` to manage merge commit messages.

The script takes JSON on **stdin** with fields: `org` (required), `id` (required), `mode` (default: `validate`).

```bash
# Show what the merge commit message should be
echo '{"org":"<ORG>","id":"<PR_ID>","mode":"show"}' | pr-merge-message.sh

# Set auto-complete with squash, transition-work-items, AND merge commit message (recommended)
echo '{"org":"<ORG>","id":"<PR_ID>","mode":"set-auto-complete"}' | pr-merge-message.sh

# Validate current merge commit message matches expected format
echo '{"org":"<ORG>","id":"<PR_ID>","mode":"validate"}' | pr-merge-message.sh

# Set only the merge commit message (without auto-complete flags)
echo '{"org":"<ORG>","id":"<PR_ID>","mode":"set"}' | pr-merge-message.sh
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
