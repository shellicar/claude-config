# claude-config — Repo Memory

## Session Protocol

**Every session follows this cycle. No exceptions.**

### On Start
1. Read this file
2. Read `.claude/sessions/` for recent session logs
3. Understand current state before doing anything

### During Work
- Use the TODO list to track all tasks — create it at session start, update as you go
- Work incrementally — one change at a time
- Mark each TODO in-progress before starting, completed immediately after finishing
- If a TODO is dropped or no longer relevant, mark it `[-]` with a brief reason — **never silently remove a task**
- Commit with descriptive messages after each meaningful change
- **Be proactive** — after completing a step, immediately state what you're doing next and move to it.

**Every TODO list MUST end with these items. They are not optional.**
**Execute them IN ORDER. Each step blocks the next.**
```
- [ ] Ask user to verify changes before marking done
- [ ] Write session log (.claude/sessions/YYYY-MM-DD.md)
- [ ] Update CLAUDE.md current state (if changed)
- [ ] Commit all changes (session log and state updates MUST be in this commit)
```

**Why this order matters:** The session log is a tracked file. If you commit first and write the log after, it either gets left out or requires a separate throwaway commit. Write the log, update state, THEN commit — one clean commit that includes everything.

### On Finish (before committing)

Do NOT invoke git-commit until steps 1-3 are done.

1. Write session log to `.claude/sessions/YYYY-MM-DD.md`:
   ```
   ### HH:MM — [area/task]
   - Did: (1-3 bullets)
   - Files: (changed files)
   - Decisions: (what and why)
   - Next: (what remains / blockers)
   ```
2. Update `Current State` below if in-progress work changed
3. Update `Recent Decisions` below if you made a structural decision
4. NOW commit — session log and state updates are included in the commit

## Current State

Branch: `main`. Clean working tree. Session log tracking active in `.claude/sessions/`.

## Architecture

Claude Code global config repo for `shellicar`. Contains skills, hooks, and settings shared across all projects.

### Key Files & Directories

| Path | Role |
|------|------|
| `CLAUDE.md` | Global protocol — commander-protocol, brewing cycle, compliance. Loads for every session everywhere. |
| `skills/{name}/SKILL.md` | Skill definition files. Loaded by the Skill tool on demand. |
| `skills/{name}/scripts/` | Executable scripts bundled with a skill. |
| `hooks/` | Shell hook scripts (e.g. `block_dangerous_commands.sh`). |
| `settings.json` | Claude Code settings — auto-approve patterns, MCP servers, hook registrations. |
| `cli-config.json` | `@shellicar/claude-cli` config (model, timeouts, auto-approval, thinking, providers). |
| `.gitignore` | Excludes runtime files: `audit.jsonl`, `cli-session`, `cache/`, `settings.local.json`, etc. |

### What is gitignored (runtime files — do NOT commit)

`audit.jsonl`, `cli-session`, `settings.local.json`, `cache/`, `plans/`, `todos/`, `node_modules/`, `context-mode/`, `*.bak`

## Conventions

- **No build process** — pure config and markdown. No compile, no type-check, no lint.
- Skills live at `skills/{skill-name}/SKILL.md`. Scripts at `skills/{skill-name}/scripts/`.
- Hook scripts live in `hooks/`. They are shell scripts — follow POSIX conventions.
- `settings.json` and `cli-config.json` are tracked — changes affect all Claude Code sessions.
- No PRs — direct commits to `main` (`shellicar-config-conventions`).

## Linting & Formatting

None. No formatters, no lint hooks.

## Key Patterns

**Skill format**: Each skill is a markdown file (`SKILL.md`) with a `# Title` heading and freeform content. The Skill tool loads and injects the content. Scripts referenced by skills live in `scripts/` alongside the SKILL.md.

**Hook scripts**: Registered in `settings.json` under `hooks`. Shell scripts — must be executable. The `block_dangerous_commands.sh` hook blocks chained commands and banned CLI operations.

**Global CLAUDE.md vs harness**: `~/.claude/CLAUDE.md` applies to ALL Claude sessions everywhere. This harness (`~/.claude/.claude/CLAUDE.md`) only applies when working in `~/.claude` as the project root.

## Known Debt / Gotchas

- First harness session — debt to be discovered.

## Recent Decisions

- Harness installed 2026-03-14: Stage 2 (harness + sessions tracked). No gitignore changes needed — `.claude/` is not blocked.
