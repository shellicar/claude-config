---
name: github-milestone
description: "Manage GitHub milestones for version tracking.\nTRIGGER when: creating PRs, attaching milestones to PRs, creating/finding/closing milestones, or any workflow involving version tracking.\nDO NOT TRIGGER when: general GitHub operations that don't involve milestones."
---

# GitHub Milestones

**Scope:** Single source of truth for milestone conventions, creation, lookup, and closing on GitHub.

## Concept

A milestone is a **forward-looking goal** — it collects work heading *toward* the next release. The shipped version is in the past; the milestone represents where you're going next.

## Format

Milestones use `x.y` format (e.g., `6.1`, `2.0`). A milestone stays open and accumulates PRs until that version ships. When it ships, close the milestone.

## Workflow

### 1. Check for open milestones

```bash
gh api repos/{owner}/{repo}/milestones --jq '.[].title'
```

### 2. If an open milestone exists → use it

It represents the current target. If multiple exist, pick the one that matches the PR's nature (e.g., a maintenance patch goes to the minor milestone, not a major).

### 3. If no open milestone exists → ask

Use `AskUserQuestion` to determine which milestone to create:

- "Next minor (x.y+1)" — e.g., `6.1` if current version is `6.0.x`
- "Next major (x+1.0)" — e.g., `7.0` if planning breaking changes

Then create it:

```bash
gh api repos/{owner}/{repo}/milestones --method POST -f title="6.1"
```

## CLI Commands

### Attach to PR

```bash
# During creation
gh pr create --title "Title" --body "Description" --milestone "6.1"

# After creation
gh pr edit <number> --milestone "6.1"
```

### Close milestone

Close when the target version ships:

```bash
gh api repos/{owner}/{repo}/milestones/{number} -X PATCH -f state=closed
```

## Integration

Other skills reference this skill for milestone operations:

- **github-pr**: Attach milestone when creating PRs
- **maintenance-release**: Attach milestone during Phase 5.4
- **github-release**: Check milestone status post-release
- **shellicar-oss-conventions**: Milestone format and linking rules
