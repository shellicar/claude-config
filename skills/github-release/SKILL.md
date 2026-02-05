---
name: github-release
description: Create a GitHub release to trigger npm publish. Use when publishing a release, cutting a new version, or releasing to npm.
user-invocable: true
---

# GitHub Release

Create a GitHub release for an npm package, triggering the npm-publish workflow.

## Quick Start

```bash
# 1. Verify version exists in package.json and CHANGELOG
# 2. Ensure PR is merged and main is up to date
# 3. Create release (no 'v' prefix for @shellicar repos)
gh release create "1.2.1" --title "1.2.1" --generate-notes
```

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
~/.claude/skills/github-pr/scripts/detect-convention.sh
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

### 2. Confirm with User

Use `AskUserQuestion` to confirm release creation:

- "Create release" - Proceed with release
- "Cancel" - Do not create release

### 3. Create Release with Auto-Generated Notes

```bash
# @shellicar convention: no 'v' prefix
gh release create "${VERSION}" \
  --title "${VERSION}" \
  --generate-notes
```

### 4. Review and Evaluate Release Notes

```bash
# Get the auto-generated release notes
gh release view "${VERSION}" --json body --jq '.body'
```

**Evaluate the notes** and provide a recommendation:

Consider:
- Do the notes capture the key changes?
- For security fixes: Is the CVE linked for searchability?
- For breaking changes: Are they clearly highlighted?
- Is important context missing?

Present the notes to the user with your assessment and recommendation:

```text
**Auto-generated notes:**
[notes here]

**Assessment:** [Your evaluation - what's good, what's missing]
**Recommendation:** [Accept as-is / Suggest specific improvement]
```

Use `AskUserQuestion` for confirmation:
- "Accept notes" - Continue to next step
- "Edit notes" - Provide suggested improvement or custom notes

### 5. Monitor npm-publish Workflow

```bash
# Check workflow status
gh run list --workflow=npm-publish.yml --limit=1 --json status,conclusion,databaseId,displayTitle
```

Wait for the workflow to complete. Report success or failure.

#### If Workflow Fails

If the workflow fails due to a fixable issue (e.g., expired npm token, transient error):

1. User fixes the issue manually (e.g., updates GitHub secret)
2. Re-run the failed workflow:

```bash
gh run rerun <run-id>
```

3. Continue monitoring until success

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
maintenance-release → github-version → git-commit → github-pr → [PR merged] → github-release
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
- Release notes: Auto-generated by GitHub (--generate-notes)
- The npm-publish workflow is triggered by release creation
- Always confirm with user before creating release
