---
name: shellicar-oss-conventions
description: |
  Git branch, commit, PR, label, and milestone conventions for @shellicar npm packages. Without it, PRs miss labels and milestones, breaking the release tracking workflow.
  TRIGGER when committing, pushing, or creating PRs in a @shellicar npm package repo.
  DO NOT TRIGGER for personal shellicar repos without a package scope.
user-invocable: false
metadata:
  category: standards
---

# @shellicar OSS Conventions

**Scope:** Git branch, commit, PR, milestone, issue linking, and repo configuration conventions for @shellicar npm packages on GitHub.

Git and PR conventions for published npm packages under the @shellicar scope.

## Detection

Match when:
- Remote URL contains `github.com/shellicar/`
- Working directory under `$HOME/repos/@shellicar/`

## Platform

- **Platform**: GitHub
- **CLI**: `gh`

## Branch Naming

- `feature/<name>` — new features
- `feature/version-<version>` (version bumps and releases)
- `fix/<name>` — bug fixes
- `docs/<name>` — documentation changes
- `security/<name>` — security fixes and vulnerability patches
- `main` (default branch)

## Commit Messages

- Concise, single line, imperative mood
- **No prefixes.** See `git-commit` skill.
- Load the `writing-style` skill.

## Assignee

Always assign `shellicar` to PRs:

```bash
gh pr create --title "Title" --body "Description" --assignee shellicar
gh pr edit --adwd-assignee shellicar
```

## Labels

Apply labels based on the nature of the changes. Use the branch prefix as a starting hint, but consider the actual content:

| Branch / Content | Label |
|------------------|-------|
| `fix/` branch, bug fixes | `bug` |
| `feature/` branch, new features | `enhancement` |
| `docs/` branch, documentation-only | `documentation` |
| `security/` branch, via pnpm overrides / dependency pins | `dependencies` |
| `security/` branch, via code changes | `bug` |
| Dependency updates | `dependencies` |

Multiple labels can apply (e.g., a bug fix that also updates docs could get `bug`).

```bash
gh pr create --title "Title" --body "Description" --label "bug"
gh pr edit --add-label "bug"
```

## PR Workflow

### 1. Milestone

Use the `github-milestone` skill for milestone management (format, creation, linking).

### 2. Reference Issues

Link related issues in the PR description using [GitHub closing keywords](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue#linking-a-pull-request-to-an-issue-using-a-keyword):

- `close`, `closes`, `closed`
- `fix`, `fixes`, `fixed`
- `resolve`, `resolves`, `resolved`

Use `Refs #123` to reference an issue without closing it.

## PR Description Format

Follow the `writing-style` skill for content. Use this template:

```markdown
## Summary

Brief description of the changes.

## Related Issues

Fixes #123
Closes #456

## Changes

- Change 1
- Change 2

```

## Co-Authorship

Include `Co-Authored-By: Claude <noreply@anthropic.com>` in the PR description (not in commits) if you would like to be credited.

## Issue and Milestone Linking

- **Issues**: Reference with closing keywords (`closes`, `fixes`, `resolves`) or `Refs #123` for non-closing references
- **Milestones**: Every PR must be linked to a milestone (see `github-milestone` skill)

## CLI Commands

```bash
# Create PR with assignee and label (milestone via github-milestone skill)
gh pr create --title "Title" --body "Description" --assignee @me --label "bug"

# Update PR
gh pr edit --title "New title" --body "New description"
gh pr edit --add-assignee shellicar
gh pr edit --add-label "bug"

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

Use the `github-repos` skill to apply these settings.

### Desired Settings

- Wiki: disabled
- Projects: disabled
- Discussions: disabled
- Issues: enabled
- Auto-merge: enabled
- Delete branch on merge: enabled
- Default branch: main

### Desired Ruleset (name: `main`)

Target: default branch. Rules:

1. `deletion`
2. `non_fast_forward`
3. `code_scanning` (CodeQL, high_or_higher)
4. `pull_request` (0 approvals, squash only)
5. `creation`
6. `required_status_checks` (omit if no CI)
