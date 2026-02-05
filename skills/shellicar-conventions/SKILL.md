---
name: shellicar-conventions
description: Git conventions for shellicar projects on GitHub. Loaded when detected as the active convention.
user-invocable: false
---

# Shellicar Conventions

Git and PR conventions for personal and OSS projects.

## Detection

Match when:
- Remote URL contains `github.com/shellicar/`
- Local email is `shellicar@gmail.com`

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

## PR Description Format

```markdown
## Summary

Brief description of the changes.

## Changes

- Change 1
- Change 2

## Test Plan

- [ ] Test case 1
- [ ] Test case 2
```

## Work Item Linking

- **Format**: None required (personal projects)
- GitHub issues can be referenced with `#123` if applicable

## CLI Commands

```bash
# Create PR
gh pr create --title "Title" --body "Description"

# Update PR
gh pr edit --title "New title" --body "New description"

# List PRs
gh pr list

# View PR
gh pr view 123
```
