---
name: git-cleanup
description: Analyze and clean up local git branches. Use when branches have accumulated, after merging PRs, or when cleaning up stale branches.
---

# Git Cleanup: Local Branch Analysis and Cleanup

Techniques for analyzing and cleaning up local git branches, especially with squash merges.

## Quick Start

```bash
# 1. Backup first!
git bundle create ~/backup-branches-$(date +%Y%m%d).bundle --all

# 2. Find branches with deleted remotes
git branch -v | grep '\[gone\]'

# 3. Delete them
git branch -d branch-name    # safe delete
git branch -D branch-name    # force delete (if -d fails)

# 4. For remaining branches, check if merged
./git-check.sh branch-name
```

## FIRST: Take a Backup!

Before any cleanup, backup your branches:

```bash
# Create a backup bundle of all local branches
git bundle create ~/backup-branches-$(date +%Y%m%d).bundle --all

# Or backup specific branches
git bundle create ~/backup-feature-branches.bundle branch1 branch2 branch3

# To restore if needed:
git bundle unbundle ~/backup-branches-20240205.bundle
```

## Overview: The Decision Process

For each local branch, determine:

1. **Is it tracked and [gone]?** → Remote deleted, likely merged via PR → Delete
2. **Does the feature already exist in main?** → Obsolete → Delete
3. **Does git-check.sh say merged?** → Content verified in main → Delete
4. **Is it abandoned/superseded?** → Old, broken, replaced → Delete
5. **Does PR investigation prove it's merged?** → Trace commits → Delete
6. **None of the above?** → Legitimate WIP → Keep

## Step 1: Quick Assessment

```bash
# List all local branches with tracking status
git branch -v
```

Key indicators:
- `[gone]` - remote branch deleted (likely merged via PR)
- `[ahead X]` - local commits not pushed to remote
- No indicator - in sync with remote

## Step 2: Run git-check.sh

```bash
# Check all branches for squash-merged content
~/dotfiles/git-check.sh --all
```

The script compares diff content from merge-base to detect if branch changes exist in main, even with squash merges.

**If it says merged** → Safe to delete
**If it says not merged** → Investigate further (may still be merged, see below)

## Step 3: For Each Unmerged Branch

**ALWAYS show the `--stat` first** to understand the scope of changes:

```bash
# Show what the branch changed from common ancestor
git diff main...branch-name --stat -w

# Show how different the branch is from current main
git diff branch-name main --stat -w
```

The second diff is crucial - if main has diverged massively (thousands of files changed), the branch is almost certainly obsolete.

### Technique A: Check if Feature Exists in Main

Before investigating merge history, check if the feature/code already exists:

```bash
# Search for the expected file
git show main:path/to/expected/file.ts 2>/dev/null

# Search for class/function names
git grep "class FeatureName" main
git grep "function featureName" main
```

**Example**: Branch `feature/add-email-address-valueobject` - check if `EmailAddress` class exists:
```bash
git grep "class EmailAddress" main
```
If found → Feature was implemented (possibly differently) → Branch is obsolete

### Technique B: Check if Branch is Abandoned/Broken

Examine the branch content:

```bash
# Look at the files changed
git diff main...branch-name --stat

# Read key files on the branch
git show branch-name:path/to/file.ts
```

Signs of abandonment:
- Old commit timestamps with no recent activity
- WIP/experimental commit messages
- Code that won't work (wrong APIs, missing dependencies)
- Approach replaced by different implementation in main

**Example**: Branch `feature/better-encryption` used Node.js crypto APIs in browser code → Won't work → Check if main has working alternative → Delete if superseded

### Technique C: Azure DevOps PR Investigation

When git-check.sh says "not merged" but you suspect it was:

#### Step 1: Find the PR by file history

```bash
# Find PRs that touched the feature's files
git log main --oneline -- path/to/feature/files/ | head -5
```

This shows merged PRs like `f7948fb8 Merged PR 475: Dashboard home page`

#### Step 2: Get PR merge details

**Option A: If you know the PR ID**
```bash
az repos pr show --id <PR_ID> --organization https://dev.azure.com/<org> \
  --query "{sourceRefName: sourceRefName, lastMergeSourceCommit: lastMergeSourceCommit.commitId, mergeStrategy: completionOptions.mergeStrategy}" \
  -o table
```

**Option B: Query from merge commit in main (Pull Request Query API)**
```bash
# Find the squash merge commit in main
git log main --oneline --grep="PR-number-or-title" | head -1
# e.g., 1ff3b1b6 Merged PR 503: Use temporal for survey workflow

# Query the API with full commit hash
az rest --method POST \
  --uri "https://dev.azure.com/<org>/<project>/_apis/git/repositories/<repo>/pullrequestquery?api-version=7.1" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798" \
  --body '{"queries": [{"items": ["<full-40-char-commit-hash>"], "type": "lastMergeCommit"}]}'
```

This returns full PR details including `pullRequestId`, `sourceRefName`, and `lastMergeSourceCommit`.

Key fields:
- `sourceRefName` - confirms which branch was merged
- `lastMergeSourceCommit.commitId` - the actual commit that was merged FROM the branch
- `mergeStrategy` - "squash" or "merge"

#### Step 3: Quick verification - compare branch tip with lastMergeSourceCommit

```bash
# Get current branch tip
git rev-parse origin/branch-name

# If branch tip == lastMergeSourceCommit → ENTIRE branch was merged
# If they differ → Check what's extra (see Technique D)
```

**Example**:
```bash
$ az repos pr show --id 475 --organization https://dev.azure.com/hopeventures \
    --query "{lastMergeSourceCommit: lastMergeSourceCommit.commitId}" -o table
LastMergeSourceCommit: dbd52fc6...

$ git rev-parse origin/feature/dashboard-features
dbd52fc6...

# Same commit! → Entire branch merged via PR 475 → Safe to delete
```

#### Alternative: Compare content if hashes differ

```bash
# Compare with PR's lastMergeSourceCommit
# Empty output = identical content = fully merged
git diff <lastMergeSourceCommit> <branch-tip> --stat
```

### Technique D: Trace Extra Commits After Merge

If branch has commits AFTER what was merged:

```bash
# Show recent commits on branch
git log --oneline branch-name | head -10
```

If PR merged commit `abc123` but branch tip is `def456`:
- Commits after `abc123` are "extra"
- These may have been merged in a subsequent PR

#### Get PR commit history

```bash
az rest --method GET \
  --uri "https://dev.azure.com/<org>/<project>/_apis/git/repositories/<repo>/pullRequests/<PR_ID>/commits?api-version=7.1" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798"
```

#### Search for branch tip in PR commit history

When a branch was rebranched (e.g., `feature/foo` → `feature/foo-v2`), the original branch commits may be included in the new branch's PR:

```bash
# Get branch tip commit
git rev-parse origin/feature/foo
# e.g., cf7b9d85e8e441678030bacf6114818a6e8d2e5e

# Get PR commits and search for it
az rest --method GET \
  --uri "https://dev.azure.com/<org>/<project>/_apis/git/repositories/<repo>/pullRequests/<PR_ID>/commits?api-version=7.1" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798" > /tmp/pr-commits.json

# Search for the commit
grep "cf7b9d85" /tmp/pr-commits.json
```

**If found** → The branch tip was included in the PR → Safe to delete original branch

**Example**: `feature/surveys/temporal` was rebranched as `feature/surveys/temporal-v2` and merged via PR 503. The original branch tip `cf7b9d85` was found in PR 503's commit history → Original branch is obsolete.

#### Prove content equivalence

```bash
# Empty --stat output = identical content
git diff <commit-A> <commit-B> --stat
```

**Example**: Branch tip `d1ccd6a3` vs PR's first commit `7bc01c02`:
```bash
git diff d1ccd6a3 7bc01c02 --stat
# (empty output) → Identical content → Extra commit was merged elsewhere
```

### Technique E: Compare Diff Ranges

When you need to prove two commit ranges have the same changes:

```bash
# Branch changes from merge-base
git diff <merge-base>..<branch-tip>

# Main changes (specific commits)
git diff <commit-before>..<commit-after>

# Compare the diffs themselves
diff <(git diff A..B) <(git diff C..D)
```

## Common Patterns We Encounter

### Pattern 1: "Dirty" branch left behind

You committed WIP to `feature/foo`, created `feature/foo-clean` for the PR, merged the clean version. Original branch has the same content (or subset).

**Detection**: PR's `lastMergeSourceCommit` differs from branch tip, but content comparison shows identical changes.

### Pattern 2: Accidental commit after merge

You committed to the branch after the PR was merged. That commit was either:
- Copied to a new branch and merged in subsequent PR
- Abandoned
- Still needed (don't delete!)

**Detection**: Branch tip has commits after `lastMergeSourceCommit`. Trace through subsequent PRs.

### Pattern 3: Branch rebased before merge

Branch tip differs from `lastMergeSourceCommit` because you rebased before merging.

**Detection**: Commit hashes differ but `git diff` shows empty (identical content).

### Pattern 4: Feature implemented differently

Branch has one approach, main has different implementation of same feature.

**Detection**: `git grep` finds the feature in main with different code.

### Pattern 5: Branch rebranched before merge

You created `feature/foo`, then rebranched to `feature/foo-v2` for the PR. The v2 branch was merged, leaving the original branch behind.

**Detection**:
1. Find the PR that merged similar content (by file path or feature name)
2. Check if PR's `sourceRefName` is a different branch (e.g., `-v2` suffix)
3. Search PR commit history for the original branch tip commit
4. If found → original branch commits were included → safe to delete

**Example**: `feature/surveys/temporal` rebranched to `feature/surveys/temporal-v2`, merged via PR 503. Branch tip `cf7b9d85` found in PR 503 commits.

### Pattern 6: Continued commits after PR, rebased and merged elsewhere

You merged a branch via PR, then accidentally continued committing to the same branch. Later, you rebased onto main and merged those extra commits via a different PR.

**Detection**:
1. Commit hashes on branch DON'T match any PR's commit history
2. But the PR merge commit message matches branch commit messages
3. Compare actual diff content - identical changes prove it was merged

**Verification technique** - compare actual file changes, not commit hashes:
```bash
# Show the branch commit's change to a specific file
git show <branch-commit> -- path/to/file.ts

# Find the PR that merged similar content
git log main --oneline --grep="<commit-message-text>"

# Show the PR merge commit's change to the same file
git show <pr-merge-commit> -- path/to/file.ts

# If the diffs are IDENTICAL → same change was merged (rebased)
```

**Example**: Branch `feature/subscription-logging` had extra commits after PR 91. Those commits were rebased onto main and merged via PR 92 from `feature/org-form`. Commit hashes differ, but comparing the actual diff shows identical changes (e.g., same line commented out in mapping.ts).

**Key insight**: When you rebase, commit hashes change but content stays the same. Always compare **actual diff content**, not just commit hashes.

## Final Cleanup

After investigation confirms branch can be deleted:

```bash
git branch -D branch-name
```

## Quick Reference

| Scenario | Check | Action |
|----------|-------|--------|
| `[gone]` in branch -v | Remote deleted | Delete |
| git-check.sh says merged | Content in main | Delete |
| Feature exists in main | `git grep` finds it | Delete |
| Code is broken/abandoned | Review shows issues | Delete |
| PR shows same content | `git diff` is empty | Delete |
| Extra commits traced | Found in later PR | Delete |
| Branch tip in rebranched PR | `grep` commit in PR history | Delete |
| Rebased commits (hash differs) | Compare actual diff content | Delete if identical |
| Legitimate WIP | None of the above | Keep |
