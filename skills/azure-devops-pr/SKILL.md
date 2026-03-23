---
name: azure-devops-pr
description: "Enforces the required sequence for creating and completing Azure DevOps PRs. Skipping steps causes incorrect work item linking.\nTRIGGER when creating or completing a pull request in Azure DevOps.\nDO NOT TRIGGER when querying PR status, reviewing PR content, or understanding PR operations. Load azure-devops-repos for reference."
user-invocable: true
metadata:
  category: workflow
---

# Azure DevOps PR Workflow

**This is the required sequence.** Follow every step in order. Do not skip steps. See `azure-devops-repos` for CLI command reference and work item linking rules.

## Workflow

Load the `writing-style` skill.

1. **Create PR** with title and description per writing-style. Mention the parent PBI/Bug with `#1234` in the `## Related Work Items` section. Do NOT include Task IDs in the description.

2. **Link Task** to the PR:

   mcp__shellicar__exec:

   ```json
   {"steps":[{"commands":[{"program":"az","args":["repos","pr","work-item","add","--id","<PR_ID>","--work-items","<TASK_ID>","--org","https://dev.azure.com/{org}"]}]}]}
   ```

   ```bash
   az repos pr work-item add --id <PR_ID> --work-items <TASK_ID> --org https://dev.azure.com/{org}
   ```

3. **Preview merge message**:

   mcp__shellicar__exec:

   ```json
   {"steps":[{"commands":[{"program":"~/.claude/skills/azure-devops-repos/scripts/pr-merge-message.sh","stdin":"{\"org\":\"<ORG>\",\"id\":\"<PR_ID>\",\"mode\":\"show\"}"}]}]}
   ```

   ```bash
   echo '{"org":"<ORG>","id":"<PR_ID>","mode":"show"}' | pr-merge-message.sh
   ```

4. **Set auto-complete with merge message**:

   mcp__shellicar__exec:

   ```json
   {"steps":[{"commands":[{"program":"~/.claude/skills/azure-devops-repos/scripts/pr-merge-message.sh","stdin":"{\"org\":\"<ORG>\",\"id\":\"<PR_ID>\",\"mode\":\"set-auto-complete\"}"}]}]}
   ```

   ```bash
   echo '{"org":"<ORG>","id":"<PR_ID>","mode":"set-auto-complete"}' | pr-merge-message.sh
   ```

For CLI commands, work item linking rules, markdown formatting, and merge message script reference, see `azure-devops-repos`.
