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

## PR Completion Workflow

Follow this exact workflow when completing a PR via CLI:

1. **Create PR** with PBI/Bug mentioned in description (`#1234` in `## Related Work Items` section). Do NOT include Task IDs in the description.
2. **Link Task** to the PR: `az repos pr work-item add --id <PR_ID> --work-items <TASK_ID> --org https://dev.azure.com/{org}`
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

The `#1234` syntax in a PR description auto-links any referenced work item. This is why only the parent (PBI/Bug) goes in the description. Putting a Task ID in the description causes it to appear as a "Related Work Item" in the sidebar, which is the wrong linking mechanism for tasks.
