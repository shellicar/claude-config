---
name: azure-devops-repos
description: "Reference for Azure DevOps PR operations: CLI commands, work item linking rules, merge commit messages, and markdown formatting.\nLoaded by azure-devops-pr for workflow steps.\nTRIGGER when managing or querying existing PRs.\nDO NOT TRIGGER when creating a new PR. Load azure-devops-pr instead."
---

# Azure DevOps Repos

**Scope:** CLI command reference for Azure DevOps PRs. For the PR creation and completion workflow, see `azure-devops-pr`. Branch policies live in `azure-devops-config`.

## Pull Requests

All PR operations use `ado-rest.sh` instead of `az repos`. The `az devops` extension has unreliable authentication — `ado-rest.sh` uses the standard `az login` AAD token directly.

```bash
# List active PRs
echo '{"org":"{org}","project":"{project}","method":"GET","path":"git/repositories/{repo}/pullrequests","params":{"searchCriteria.status":"active","api-version":"7.1"}}' | ~/.claude/skills/azure-devops/scripts/ado-rest.sh

# Show PR details
echo '{"org":"{org}","project":"{project}","method":"GET","path":"git/repositories/{repo}/pullrequests/{id}","params":{"api-version":"7.1"}}' | ~/.claude/skills/azure-devops/scripts/ado-rest.sh

# Create PR
~/.claude/skills/azure-devops/scripts/ado-rest.sh << 'EOF'
{
  "org": "{org}", "project": "{project}", "method": "POST",
  "path": "git/repositories/{repo}/pullrequests", "params": {"api-version": "7.1"},
  "body": {"sourceRefName": "refs/heads/<branch>", "targetRefName": "refs/heads/main", "title": "Title", "description": "Description"}
}
EOF

# Update PR (auto-complete, merge options)
~/.claude/skills/azure-devops/scripts/ado-rest.sh << 'EOF'
{
  "org": "{org}", "project": "{project}", "method": "PATCH",
  "path": "git/repositories/{repo}/pullrequests/{id}", "params": {"api-version": "7.1"},
  "body": {
    "autoCompleteSetBy": {"id": "<user-id>"},
    "completionOptions": {"mergeStrategy": "squash", "deleteSourceBranch": true, "transitionWorkItems": true}
  }
}
EOF

# Link work items (tasks) to PR
az repos pr work-item add --id <PR_ID> --work-items <TASK_ID> --org https://dev.azure.com/{org}
```

## Linking Work Items to PRs

There are two types of work items linked to a PR. They use **different mechanisms**. Getting this wrong causes the wrong work items to appear in the "Related Work Items" section of the PR.

| Work item type | Where it goes | How to link |
|----------------|---------------|-------------|
| **PBI or Bug** (the parent) | PR description — `## Related Work Items` section | `#1234` syntax in the description text. Azure DevOps auto-links it. |
| **Task** (the child you created for this work) | Linked to the PR via CLI | `az repos pr work-item add --id <PR_ID> --work-items <TASK_ID>` |

**CRITICAL**: Only the PBI/Bug goes in the description. The Task does **NOT** go in the description. The `#1234` syntax auto-links any work item it touches, so putting the Task ID in the description causes it to appear as a related work item instead of a properly linked task. This is the wrong result.

**The rule**: mention the parent (PBI/Bug), link the child (Task) via API. Never put Task IDs in the PR description.

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

The `#1234` syntax in a PR description auto-links any referenced work item. This is why only the parent (PBI/Bug) goes in the description. Putting a Task ID in the description causes it to appear as a "Related Work Item" in the sidebar, which is the wrong linking mechanism for tasks.
