---
name: backlog-management
description: "Collaborative workflow for grooming and re-prioritising the Azure DevOps backlog. Without it, backlog reviews are unstructured and systematic issues (orphaned items, stale work, area path mismatches) go unidentified.\nTRIGGER when organising backlogs, triaging work, or reviewing priorities.\nDO NOT TRIGGER for creating or updating individual work items."
user-invocable: true
metadata:
  category: workflow
---

# Backlog Management

**Scope: Workflows for grooming, triaging, prioritising, and capturing new work on backlogs.**

For work item CRUD and CLI commands, see `azure-devops-boards`. For hierarchy philosophy, see `work-organisation`.

## Backlog Priority Field

Azure DevOps uses `Microsoft.VSTS.Common.BacklogPriority` (a float) to order items on the backlog. This value is set automatically when items are reordered via drag-and-drop in the UI.

```bash
# Query features in backlog priority order (matches UI backlog view)
az boards query --wiql "SELECT [System.Id], [System.Title], [Microsoft.VSTS.Common.BacklogPriority] \
  FROM WorkItems WHERE [System.WorkItemType] = 'Feature' \
  AND [System.IterationPath] UNDER '<Project>\<IterationParent>' \
  AND [System.State] NOT IN ('Done', 'Removed') \
  ORDER BY [Microsoft.VSTS.Common.BacklogPriority]" -o json
```

**Note**: Backlog priority (drag-and-drop ordering) can only be changed via the UI or the undocumented Settings API. Use iteration assignment and state to influence effective priority when CLI-only.

## Backlog Organisation Workflow

### 1. Understand the Current State
Query the backlog in priority order for the relevant team/level. Present a numbered list showing: order, ID, title, state, area, parent.

```bash
# Features for a team (use iteration to scope to team)
az boards query --wiql "SELECT [System.Id], [System.Title], [System.State], \
  [System.AreaPath], [Microsoft.VSTS.Common.BacklogPriority] \
  FROM WorkItems WHERE [System.WorkItemType] = 'Feature' \
  AND [System.IterationPath] UNDER '<Project>\Project\FPR' \
  AND [System.State] NOT IN ('Done', 'Removed') \
  ORDER BY [Microsoft.VSTS.Common.BacklogPriority]" -o json
```

### 2. Identify Issues
Check for:
- **Orphaned items**: No parent, or parent in wrong hierarchy level
- **Misplaced area paths**: Area doesn't match the app/component the work is in
- **Bare iteration paths**: Features/PBIs/Tasks at the top-level iteration instead of a specific one
- **Stale items**: Old items still marked as New/Active that should be Done, Removed, or moved to a Future iteration
- **Cross-area children**: Tasks under a PBI where the task's area doesn't match its actual app context

### 3. Review Priority Order
Walk through the backlog with the user:
- Items actively In Progress should generally be near the top
- Items in earlier iterations (current/next sprint) above later ones
- Dependencies: items that block others should be prioritised higher
- Present the current order and ask if anything needs to move

### 4. Apply Changes
Use batch update scripts for bulk changes (write to `/tmp/` and execute — see `cli-tools` skill):
- Reparenting: `az boards work-item relation add/remove`
- Area/iteration changes: `az boards work-item update --area/--iteration`
- State changes: `az boards work-item update --state`
- Clearing date fields: `az boards work-item update --fields "Microsoft.VSTS.Scheduling.StartDate="`

### 5. Verify
Re-query the backlog after changes and present the updated view. Compare with the UI if the user has it open.
