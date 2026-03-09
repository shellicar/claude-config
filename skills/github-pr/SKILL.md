---
name: github-pr
description: "Create or update a GitHub pull request with a summary of changes.\nTRIGGER when: creating PRs, updating PRs, pushing for review, or asked to open a PR on GitHub.\nDO NOT TRIGGER when: reading PR status, exploring PR history, or non-PR git operations."
allowed-tools: Bash(~/.claude/skills/github-pr/scripts/*)
---

# GitHub PR Workflow

**Scope:** Steps and CLI commands for creating or updating a GitHub pull request. PR format and conventions live in convention skills.

Create or update a pull request with a detailed summary of changes.

## Working Directory

Always `cd` to the project directory first, then use bare `git` and `gh` commands (e.g., `git status`, not `git -C /path status`). This ensures commands match auto-approve patterns in the user's permission settings.

## Script Dependencies

This skill uses helper scripts in `~/.claude/skills/github-pr/scripts/`:

| Script | Purpose |
|--------|---------|
| `github-pr-info.sh` | Gather all PR state: branch, merged PR, existing PR, ancestor, commits, diffstat |
| `create-github-pr.sh` | Create PR with enforced required parameters (--title, --body, --milestone, --assignee) |

## Usage

### 1. Gather PR State

Run the gather script to collect all PR-related state in one call:

```bash
~/.claude/skills/github-pr/scripts/github-pr-info.sh
```

The script calls `detect-convention` internally and outputs `Convention: <name>` in the header.

The script outputs structured sections: `BRANCH`, `DEFAULT_BRANCH`, `MERGED_PR`, `EXISTING_PR`, `ANCESTOR`, `COMMITS`, `MILESTONES`, `DIFFSTAT`.

After running the script, load the `<convention>-conventions` skill if `Convention:` is present in the output. If not present, proceed without convention-specific rules.

### 2. Analyse the Gathered State

From the script output, check the following — stop and inform the Supreme Commander if any fail:

- **On default branch**: If `BRANCH` equals `DEFAULT_BRANCH`, STOP — a PR cannot be created from the default branch.
- **Already merged**: If `MERGED_PR` is not empty, STOP — the branch was already merged. Inform the Supreme Commander.
- **Existing PR**: If `EXISTING_PR` is not empty, this is an update — use `gh pr edit` instead of creating a new PR.
- **No commits**: If `COMMITS` is empty, STOP — there is nothing to create a PR for.

### 3. Create PR Content

**Title**: Short summary (under 70 characters), imperative mood.

**Body**: Depends on the type of changes. See scenarios below.

#### Scenario: Security / maintenance release

Use when the branch contains audit fixes, dependency updates, or both (typically from the `maintenance-release` skill).

```markdown
## Summary

- Fix N vulnerabilities (X high, Y moderate, Z low) via pnpm overrides
- Update @shellicar/build-clean to 1.2.4, @shellicar/build-graphql to 1.4.3
- Update all minor/patch dependencies

## Security Advisories

- [GHSA-xxxx-xxxx-xxxx](https://github.com/advisories/GHSA-xxxx-xxxx-xxxx) package-name vulnerability title
- [GHSA-yyyy-yyyy-yyyy](https://github.com/advisories/GHSA-yyyy-yyyy-yyyy) package-name vulnerability title
```

**Key rules:**
- Every unique GHSA MUST be listed individually with a link
- Use the GHSA ID as the link text (not the CVE ID)
- Include a short description: package name + vulnerability type
- The Summary section describes what was done at a high level
- Deduplicate: if the same GHSA appears for multiple version ranges, list it once

#### Scenario: Version bump

Use when the PR only bumps the version and updates CHANGELOG.

The commit message is sufficient as both the title and body (e.g. "Bump version to 1.2.4").

#### Scenario: Feature / fix / other

Based on loaded convention skill:
- **Description**: See style guide below
- **Work Items**: Link format per convention (e.g., `#123`, `AB#1234`)

#### PR Description Style Guide

See `writing-style` skill for the full style guide. Key points:
- Describe **what** was done, not **how** it was implemented
- `## Summary` heading with 3-5 bullet points maximum
- Short phrases, not full sentences
- If the title says it all, an empty body is fine

### 4. Resolve Milestone (GitHub)

You MUST load the `github-milestone` skill and resolve the milestone BEFORE creating the PR. The milestone is a required parameter for `gh pr create`.

Follow the milestone skill's workflow:
1. Check for open milestones
2. If one exists, use it
3. If none exists, ask the user which to create

### 5. Create or Update PR

**GitHub** (create) — use the enforcement script:

```bash
~/.claude/skills/github-pr/scripts/create-github-pr.sh \
  --title "Title" \
  --body "Description" \
  --milestone "1.3" \
  --assignee "@me" \
  --label "dependencies"
```

The script requires `--title`, `--body`, `--milestone`, and `--assignee`. It will reject the call if any are missing. `--label` is optional and repeatable.

Do NOT use `gh pr create` directly — the enforcement script exists to prevent skipping required parameters.

**GitHub** (update):
```bash
gh pr edit --title "Title" --body "Description"
```

After creating a PR, **always link the PR URL** back to the user so they can review it.

**Azure DevOps** (via convention):
```bash
az repos pr create --title "Title" --description "Description"
# or
az repos pr update --id ID --title "Title" --description "Description"
```

## Auto-Merge (GitHub)

After creating a PR, use `AskUserQuestion` to offer auto-merge:

- "Enable auto-merge" - Merges automatically when checks pass
- "Manual merge" - Leave for manual merge later

If auto-merge selected:

```bash
gh pr merge --auto --squash
```

## Post-Creation Verification (GitHub)

After creating a PR (and optionally enabling auto-merge), verify the PR is not blocked. Add a todo item to track this.

### 1. Check PR Status

```bash
gh pr view <number> --json state,mergeable,mergeStateStatus,statusCheckRollup
```

Key fields:
- `mergeStateStatus`: `CLEAN` (ready to merge), `BLOCKED` (checks failing or rules preventing merge), `BEHIND` (needs rebase)
- `mergeable`: `MERGEABLE`, `CONFLICTING`, `UNKNOWN`
- `statusCheckRollup`: Array of check runs with `name`, `status`, `conclusion`

### 2. Diagnose Failures

If `mergeStateStatus` is `BLOCKED`, inspect the `statusCheckRollup` for any checks with `conclusion: FAILURE`:

```bash
# Get the run ID from the detailsUrl in statusCheckRollup, then:
gh run view <run-id> --log-failed
```

This shows the failed step's logs, which usually reveals the root cause (e.g., audit failure, test failure, lint error).

### 3. Report and Recommend

After diagnosis, report:
- Which check(s) failed
- The root cause from the logs
- Whether the failure is **introduced by this PR** or **pre-existing on the default branch**
- Recommended action (fix in this PR, fix in a separate PR first, etc.)

If the failure is pre-existing on the default branch, recommend fixing it in a separate branch/PR so it unblocks all PRs, not just this one.

## Post-Merge Cleanup (GitHub)

After a PR is merged, clean up branches:

### 1. Verify Branch Content is Merged

Check that the branch changes exist in the default branch (handles squash merges):

```bash
# Fetch latest
git fetch origin

# Get branch diff content
BASE=$(git merge-base HEAD origin/<default-branch>)
BRANCH_DIFF=$(git diff $BASE HEAD | sed -n '/^---/!p' | sed -n '/^+++/!p' | sed -n '/^@@/!p' | sed -n '/^index /!p')

# Check if the default branch contains the same changes
# (Compare against recent commits in the default branch)
```

Alternatively, use `~/dotfiles/git-check.sh <branch>` if available.

### 2. Delete Remote Branch

```bash
git push origin --delete <branch-name>
```

### 3. Prune Stale Remote References

```bash
git fetch -p
```

### 4. Delete Local Branch

```bash
git switch <default-branch>
git branch -D <branch-name>
```

### Post-Merge Flow

After merge is confirmed, use `AskUserQuestion` with **two questions**:

1. **Release**: "Create a release?" (triggers `github-release` skill)
   - "Create release" - Run github-release workflow
   - "Skip release" - No release now

2. **Cleanup**: "Clean up branches?"
   - "Clean up branches" - Delete remote and local branches, switch to default branch
   - "Keep branches" - Leave branches for manual cleanup

## Convention Requirements

Convention skills must define:
- `platform`: `github` or `azure-devops`
- `work_item_format`: How to link work items in PR description
- `pr_template`: Structure for PR description
