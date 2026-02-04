---
name: shellicar-oss-conventions
description: Git conventions for @shellicar published npm packages (GitHub)
user-invocable: false
---

# @shellicar OSS Conventions

Git and PR conventions for published npm packages under the @shellicar scope.

## Detection

Match when:
- Remote URL contains `github.com/shellicar/`
- Working directory under `$HOME/repos/@shellicar/`

## Platform

- **Platform**: GitHub
- **CLI**: `gh`

## Branch Naming

- `feature/<name>`
- `fix/<name>`
- `main` (default branch)

## Commit Messages

- Concise, single line
- Imperative mood
- No prefix conventions required

## PR Workflow

### 1. Check for Milestone

Before creating a PR, ensure a milestone exists for the next version:

```bash
gh api repos/{owner}/{repo}/milestones --jq '.[].title'
```

If no milestone exists for the next version, create one:

```bash
gh api repos/{owner}/{repo}/milestones --method POST -f title="1.2.0"
```

**Version format**: Use `x.y.z` (no `v` prefix).

### 2. Link PR to Milestone

When creating/updating the PR, attach the milestone:

```bash
gh pr create --title "Title" --body "Description" --milestone "1.2.0"
gh pr edit --add-milestone "1.2.0"
```

### 3. Reference Issues

Link related issues in the PR description using GitHub keywords:

- `Fixes #123` - closes the issue when PR merges
- `Closes #123` - same as Fixes
- `Resolves #123` - same as Fixes
- `Refs #123` - references without closing

## PR Description Format

```markdown
## Summary

Brief description of the changes.

## Related Issues

Fixes #123
Closes #456

## Changes

- Change 1
- Change 2

## Test Plan

- [ ] Test case 1
- [ ] Test case 2

---
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Co-Authorship

When Claude writes or substantially modifies code, include co-author credit in the PR description (not in commits).

## Issue and Milestone Linking

- **Issues**: Reference with `Fixes #123`, `Closes #123`, or `Refs #123`
- **Milestones**: Every PR must be linked to a version milestone

## CLI Commands

```bash
# Milestones
gh api repos/{owner}/{repo}/milestones --jq '.[].title'
gh api repos/{owner}/{repo}/milestones --method POST -f title="1.2.0"

# Create PR with milestone
gh pr create --title "Title" --body "Description" --milestone "1.2.0"

# Update PR
gh pr edit --title "New title" --body "New description"
gh pr edit --add-milestone "1.2.0"

# List PRs
gh pr list

# View PR
gh pr view 123

# List issues
gh issue list
gh issue view 123
```

## Package-Specific Considerations

- Ensure version bumps follow semver
- Update CHANGELOG.md if present
- Consider npm publish implications

## Repository Configuration

### Standard Settings

All @shellicar repos should have consistent settings:

```bash
# Disable unused features
gh repo edit --enable-wiki=false
gh repo edit --enable-projects=false
gh repo edit --enable-discussions=false

# Enable issues
gh repo edit --enable-issues=true

# Set default branch
gh repo edit --default-branch main
```

### Rulesets

For bulk ruleset management across all @shellicar repos, use the ecosystem scripts:

```bash
# Sync rulesets across all repos (dry-run by default)
~/repos/@shellicar/ecosystem/scripts/sync-rulesets.sh

# Actually apply changes
~/repos/@shellicar/ecosystem/scripts/sync-rulesets.sh -d
```

Query existing rulesets for a single repo:

```bash
gh api repos/{owner}/{repo}/rulesets --jq '.[] | {name, enforcement}'
gh api repos/{owner}/{repo}/rulesets/{id}  # Full details
```

Standard ruleset for @shellicar repos (name: `main`):

- **Target**: Default branch (`~DEFAULT_BRANCH`)
- **Rules** (6 total):
  1. `deletion` - prevent branch deletion
  2. `non_fast_forward` - prevent force push
  3. `code_scanning` - CodeQL required (high_or_higher threshold)
  4. `pull_request` - require PR (0 approvals, squash merge only)
  5. `creation` - prevent direct branch creation
  6. `update` - prevent direct pushes

Example ruleset JSON structure:

```json
{
  "name": "main",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}
  },
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "code_scanning", "parameters": {
      "code_scanning_tools": [{"tool": "CodeQL", "security_alerts_threshold": "high_or_higher", "alerts_threshold": "errors"}]
    }},
    {"type": "pull_request", "parameters": {
      "required_approving_review_count": 0,
      "allowed_merge_methods": ["squash"]
    }},
    {"type": "creation"},
    {"type": "update"}
  ]
}
```

### Verify Configuration

```bash
# Check repo settings
gh repo view --json hasIssuesEnabled,hasWikiEnabled,hasProjectsEnabled,hasDiscussionsEnabled

# Check rulesets
gh api repos/{owner}/{repo}/rulesets --jq '.[].name'
```
