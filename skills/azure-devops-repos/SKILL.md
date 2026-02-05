---
name: azure-devops-repos
description: PRs and merge workflows in Azure DevOps. Use when creating/managing PRs, setting auto-complete, linking work items to PRs, or configuring merge commit messages.
---

# Azure DevOps Repos

Pull requests, work item linking, and merge workflows. See also `azure-devops-boards` for work item hierarchy and formatting.

## When Invoked

If the user invokes this skill, they likely want help with:
- **Creating** PRs with proper descriptions and work item links
- **Managing** PRs (updating, reviewing, completing)
- **Auto-complete** setup with merge commit messages
- **Branch** operations and policies

Ask what they need help with if not clear from context.

## Pull Requests

```bash
# List active PRs
az repos pr list --status active --repository <Repo> --project <Project> -o table

# Show PR details
az repos pr show --id <ID> -o json | jq '{title: .title, description: .description}'

# Update PR title
az repos pr update --id <ID> --title "New title"

# Update PR description
az repos pr update --id <ID> --description "$(cat description.md)"

# Create PR
az repos pr create --title "Title" --description "$(cat description.md)" --source-branch <branch> --target-branch main

# Set auto-complete (always do this after creating PR)
az repos pr update --id <ID> --auto-complete true

# Link work items to PR (via work item feature, not description)
az repos pr work-item add --id <PR_ID> --work-items <WI_ID1> <WI_ID2>
```

## Linking Work Items to PRs

- **PBI**: Link in the PR description using `#1234` syntax
- **Tasks**: Link via the work item feature using `az repos pr work-item add`

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
