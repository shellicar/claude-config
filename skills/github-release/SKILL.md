---
name: github-release
description: Create a GitHub release to trigger npm publish. Use when publishing a release, cutting a new version, or releasing to npm.
user-invocable: true
---

# GitHub Release

**Scope:** Steps and CLI commands for creating a GitHub release to trigger npm publish.

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

## Progress Tracking

Create TODOs at the start of this workflow. The post-release steps (monitor workflow, verify npm) are easy to lose track of if the conversation goes on a tangent — TODOs persist and serve as reminders.

```
- Gather pre-release state and verify preconditions
- Create release
- Review release notes
- Verify npm publish succeeded
```

## Steps

### 1. Gather pre-release state

Run the gather script to check all preconditions in one call:

```bash
~/.claude/skills/github-release/scripts/github-release-info.sh
```

The script calls `detect-convention` internally and outputs `Convention: <name>` in the header. Must be a GitHub repo (`shellicar` or `shellicar-oss` convention) — stop if convention is missing or does not match.

The script outputs structured sections: `REPO`, `BRANCH`, `WORKING_TREE`, `VERSION`, `CHANGELOG`, `MILESTONE`, `EXISTING`.

### 2. Analyse the gathered state

From the script output, check the following — stop and inform the Supreme Commander if any fail:

- **Branch**: Must be on `main`
- **Working tree**: Must be clean
- **Version**: Must be found in package.json
- **CHANGELOG**: Must contain an entry for the version
- **Milestone**: Should exist for the version (warn if missing, don't block)
- **Existing release**: If a release already exists, STOP — inform the Supreme Commander

### 3. Confirm with user

Use `AskUserQuestion` to confirm release creation:

- "Create release" - Proceed with release
- "Cancel" - Do not create release

### 4. Create release

Detect whether the version is a pre-release by checking for a hyphen (e.g., `1.0.0-alpha.62`, `1.2.1-preview.1`). If it contains a hyphen, add the `--prerelease` flag.

```bash
# @shellicar convention: no 'v' prefix
# Stable release:
gh release create "${VERSION}" \
  --title "${VERSION}" \
  --generate-notes

# Pre-release (version contains a hyphen):
gh release create "${VERSION}" \
  --title "${VERSION}" \
  --generate-notes \
  --prerelease
```

### 5. Review and evaluate release notes

```bash
gh release view "${VERSION}" --json body --jq '.body'
```

**Evaluate the notes** and provide a recommendation:

Consider:
- Do the notes capture the key changes?
- For security fixes: Is the CVE linked for searchability?
- For breaking changes: Are they clearly highlighted?
- Is important context missing?

Present the notes to the user with your assessment. Use `AskUserQuestion`:
- "Accept notes" - Continue
- "Edit notes" - Provide suggested improvement or custom notes

### 6. Monitor post-release status

Run the status script to check workflow, npm, and milestone:

```bash
~/.claude/skills/github-release/scripts/github-release-status.sh "${VERSION}"
```

The script outputs structured sections: `WORKFLOW`, `NPM`, `MILESTONE`.

From the output:

- **Workflow**: If in progress, wait and re-run the script. If failed, report to user — they may need to fix and re-run (`gh run rerun <run-id>`).
- **NPM**: Confirm the version is live. If pending, wait and re-run.
- **Milestone**: See `github-milestone` skill. Do **not** auto-close for patch releases — milestones use `x.y` format and stay open across the minor series.

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
- Pre-release versions (containing `-`) must use `--prerelease` flag
