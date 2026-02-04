---
name: github-release
description: Create a GitHub release to trigger npm publish workflow
user-invocable: true
---

# GitHub Release

Create a GitHub release for an npm package, triggering the npm-publish workflow.

## Context Awareness

This skill can be invoked:

1. **From conversation context**: Repo and version already known from prior discussion (most common)
2. **From working directory**: If inside a specific repo directory
3. **Ambiguous**: If in a parent workspace (e.g., `@shellicar/`) with no prior context

### Priority Order

1. **Check conversation context first** - If repo/version discussed earlier, use that
2. **Check working directory** - If in a git repo with package.json, use that
3. **Ask user** - If ambiguous (parent workspace, no context), ask which repo to release

## Pre-conditions (Discovery)

### 1. Determine Repository

**From context**: Check if a repo was discussed in the conversation (e.g., "build-clean v1.2.1")

**From working directory** (if no context):

```bash
# Check if in a git repo
git rev-parse --git-dir 2>/dev/null

# Get repo name from git remote
git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | cut -d'/' -f2
```

**If in parent workspace** (e.g., `/home/stephen/repos/@shellicar`):

Use `AskUserQuestion` to ask which repo to release, listing available repos.

### 2. Detect Convention

```bash
~/.claude/skills/git-pr/scripts/detect-convention.sh
```

Must be a GitHub repo (shellicar or shellicar-oss convention).

### 3. Get Version from package.json

```bash
# Monorepo (packages/*/package.json)
jq -r '.version' packages/*/package.json 2>/dev/null | head -1

# Single package (fallback)
jq -r '.version' package.json 2>/dev/null
```

### 4. Verify Pre-conditions

Before proceeding, verify:

- [ ] On `main` branch
- [ ] Working directory clean (no uncommitted changes)
- [ ] CHANGELOG.md contains entry for this version
- [ ] package.json version matches CHANGELOG version
- [ ] Milestone exists for this version

```bash
# Check milestone exists
gh api repos/{owner}/{repo}/milestones --jq '.[] | select(.title == "{VERSION}")'
```

If any fail, inform user what's missing.

## Main Steps

### 1. Check for Existing Release

```bash
# Note: @shellicar repos use VERSION without 'v' prefix
gh release view "${VERSION}" 2>/dev/null
```

If release exists, inform user and stop (or offer to view it).

### 2. Extract Release Notes from CHANGELOG

Parse CHANGELOG.md for the current version's section:

```bash
# Extract section between version headers
sed -n "/^## \[${VERSION}\]/,/^## \[/p" CHANGELOG.md | sed '$d'
```

If no CHANGELOG entry found, ask user what notes to use.

### 3. Confirm with User

Use `AskUserQuestion` to confirm:

```text
Ready to create release ${VERSION} for {repo}

Release notes:
---
{extracted notes}
---

This will trigger the npm-publish workflow.
```

Options: "Create release", "Cancel"

### 4. Create Release

```bash
# @shellicar convention: no 'v' prefix
gh release create "${VERSION}" \
  --title "${VERSION}" \
  --notes "${NOTES}"
```

### 5. Verify Release Created

```bash
# Check release was created
gh release view "${VERSION}"
```

Report the release URL to user.

### 6. Review Release Notes

```bash
# Get auto-generated release notes
gh release view "${VERSION}" --json body --jq '.body'
```

Show the user the auto-generated notes and confirm they are adequate. Offer to edit if needed.

### 7. Monitor npm-publish Workflow

```bash
# Check workflow status
gh run list --workflow=npm-publish.yml --limit=1 --json status,conclusion,databaseId,displayTitle
```

Wait for the workflow to complete. Report success or failure.

### 8. Confirm npm Availability

```bash
# Verify package is published
npm view @shellicar/{package-name} version
```

Confirm the new version is available on npm.

### 9. Close Milestone

After all checks pass, close the milestone:

```bash
# Get milestone number
MILESTONE_NUMBER=$(gh api repos/{owner}/{repo}/milestones --jq '.[] | select(.title == "${VERSION}") | .number')

# Close milestone
gh api repos/{owner}/{repo}/milestones/${MILESTONE_NUMBER} -X PATCH -f state=closed
```

Report milestone closed to user.

## Integration with Other Skills

**Typical flow:**
```
maintenance-release → version-management → git-commit → git-pr → [PR merged] → github-release
```

When called after other skills, version context flows through the conversation - no need to re-discover.

## CLI Reference

```bash
# Create release (no 'v' prefix for @shellicar repos)
gh release create "1.2.1" --title "1.2.1" --generate-notes

# Create with custom notes
gh release create "1.2.1" --title "1.2.1" --notes "Release notes here"

# View release
gh release view "1.2.1"

# List releases
gh release list

# Delete release (if needed)
gh release delete "1.2.1" --yes
```

## Notes

- Tag format: `${VERSION}` (e.g., `1.2.1`) - NO `v` prefix for @shellicar repos
- Release title: Same as tag (version number only)
- Release notes: Extracted from CHANGELOG.md
- The npm-publish workflow is triggered by release creation
- Always confirm with user before creating release
