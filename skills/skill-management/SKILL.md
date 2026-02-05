---
name: skill-management
description: Guidelines for creating and maintaining Claude Code skills. Use when creating new skills, updating skill descriptions, or reviewing skill organization.
user-invocable: false
---

# Skill Management

Guidelines for creating and maintaining Claude Code skills in this repository.

## Official Documentation

Full reference: https://code.claude.com/docs/en/skills

## Skill Structure

Each skill is a directory with `SKILL.md` as the entrypoint:

```
skill-name/
├── SKILL.md           # Main instructions (required)
├── scripts/           # Helper scripts (optional)
└── examples/          # Example files (optional)
```

## Frontmatter Reference

```yaml
---
name: skill-name                    # Lowercase, hyphens, max 64 chars
description: What and when          # CRITICAL - see below
user-invocable: true                # Show in / menu (default: true)
disable-model-invocation: true      # Prevent auto-loading (default: false)
allowed-tools: Bash(pattern *)      # Tools without permission prompts
context: fork                       # Run in subagent
agent: Explore                      # Subagent type when context: fork
---
```

## Writing Good Descriptions

**The description must answer TWO questions:**
1. **WHAT** does this skill do?
2. **WHEN** should it be used?

The skill content (HOW) is loaded when invoked.

### Pattern

```
[What it does]. [When to use it].
```

### Examples

**Good:**
```yaml
description: Create a git commit with a concise message. Use when committing changes, asked to commit, or after completing a task.
```

**Bad:**
```yaml
description: Create a git commit with a concise message
# Missing: WHEN to use it
```

### Description Patterns by Skill Type

| Type | Pattern | Example |
|------|---------|---------|
| Task skills | "[Action]. Use when [trigger]." | "Create a GitHub release. Use when publishing a release or cutting a new version." |
| Guideline skills | "[Guidelines for X]. Apply when [context]." | "Guidelines for POSIX shell scripts. Apply when writing or reviewing .sh files." |
| Convention skills | "[Conventions for X]. Loaded when detected as the active convention." | "Git conventions for Flightrac. Loaded when detected as the active convention." |
| Mandatory skills | "MANDATORY: Must be read at the start of every response. [What it defines]." | "MANDATORY: Must be read at the start of every response. Defines teapot mode mechanics." |

## Invocation Control

| Setting | You invoke | Claude invokes | Use case |
|---------|------------|----------------|----------|
| (default) | Yes | Yes | Most skills |
| `disable-model-invocation: true` | Yes | No | Side effects, user-controlled timing (deploy, release) |
| `user-invocable: false` | No | Yes | Background knowledge, auto-detected conventions |

## Skill Organization

### Naming Conventions

**Workflow groups** - related skills share a prefix:
- `github-version`, `github-pr`, `github-release` (npm package workflow)
- `azure-devops-boards`, `azure-devops-repos`, `azure-devops-pipelines`

**Convention skills** - named by project/context:
- `shellicar-conventions`, `flightrac-conventions`, `eagers-conventions`

### Cross-References

When skills reference each other, use the skill name:
```markdown
Invoke the `github-pr` skill to create the pull request.
```

When renaming skills, update all cross-references:
```bash
grep -r "old-skill-name" skills/
```

## Maintenance Checklist

When creating or updating skills:

1. **Name**: Lowercase, hyphens, descriptive
2. **Description**: Includes WHAT and WHEN
3. **Invocation**: Correct `user-invocable` and `disable-model-invocation` settings
4. **Cross-references**: All references to other skills are current
5. **Script paths**: Any `allowed-tools` paths match actual locations

## Convention Detection

Convention skills use `user-invocable: false` because they're loaded by a detection mechanism, not directly invoked. The detection script determines which convention applies based on:
- Git remote URL
- Repository structure
- Other contextual signals

Located at: `~/.claude/skills/github-pr/scripts/detect-convention.sh`

## Supporting Files

Keep `SKILL.md` focused. Move detailed content to supporting files:
- `reference.md` - detailed API docs
- `examples.md` - usage examples
- `scripts/` - helper scripts

Reference from SKILL.md:
```markdown
For complete API details, see [reference.md](reference.md)
```

## String Substitutions

Available in skill content:
- `$ARGUMENTS` - all arguments passed when invoking
- `$ARGUMENTS[N]` or `$N` - specific argument by index
- `${CLAUDE_SESSION_ID}` - current session ID
