---
name: shellicar-config-conventions
description: Git conventions for personal config repos (GitHub, no PRs)
user-invocable: false
---

# Shellicar Config Conventions

Git conventions for personal configuration repositories.

## Detection

Match when:
- Remote URL contains `github.com/shellicar/`
- Working directory is `$HOME/.claude` or `$HOME/dotfiles`

## Platform

- **Platform**: GitHub
- **CLI**: `gh`

## Workflow

Config repos use a simplified workflow:

- **No PRs** - commit directly to main
- **No branches** - work on main
- **No work items** - these are personal config repos

## Commit Messages

- Concise, single line
- Imperative mood
- No prefix conventions required

## CLI Commands

```bash
# Commit and push
git add -A && git commit -m "message" && git push

# View history
git log --oneline -10
```

## Notes

- These repos contain personal configuration (dotfiles, editor settings, etc.)
- Changes are typically small and don't warrant PR review
- Direct commits to main are expected
