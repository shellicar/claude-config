---
name: shellicar-conventions
description: |
  Git branch, commit, PR, and repo configuration conventions for shellicar GitHub projects. Without it, PRs miss required format and repo settings drift.
  TRIGGER when committing, pushing, or creating PRs in a shellicar GitHub project.
  DO NOT TRIGGER for @shellicar OSS packages (use shellicar-oss-conventions).
user-invocable: false
metadata:
  category: standards
---

# Shellicar Conventions

**Scope:** Git branch, commit, PR, and repo configuration conventions for shellicar projects on GitHub.

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
- `feature/version-<version>` (version bumps and releases)
- `fix/<name>`
- `main` (default branch)

## Commit Messages

- Concise, single line, imperative mood
- **No prefixes.** See `git-commit` skill.
- Load the `writing-style` skill.

## PR Description Format

Follow the `writing-style` skill for content. Use this template:

```markdown
## Summary

Brief description of the changes.

## Changes

- Change 1
- Change 2

```

## Co-Authorship

Include `Co-Authored-By: Claude <noreply@anthropic.com>` in the PR description (not in commits) if you would like to be credited.

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
