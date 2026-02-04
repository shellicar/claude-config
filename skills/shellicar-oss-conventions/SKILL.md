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

## Package-Specific Considerations

- Ensure version bumps follow semver
- Update CHANGELOG.md if present
- Consider npm publish implications
