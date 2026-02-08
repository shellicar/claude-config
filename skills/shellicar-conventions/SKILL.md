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

## Repository Configuration

Use the `github-repos` skill to apply these settings.

### Desired Settings

- Wiki: disabled
- Projects: disabled
- Discussions: disabled
- Issues: disabled
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
