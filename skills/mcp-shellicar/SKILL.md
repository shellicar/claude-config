---
name: mcp-shellicar
description: How to use the mcp__shellicar__exec MCP tool to execute commands when the Bash tool is replaced. TRIGGER when: executing shell commands, running programs, calling git, running builds/tests/scripts, or any task that would normally use the Bash tool. DO NOT TRIGGER when: reading files, editing code, searching code, or non-execution tasks.
---

# Exec MCP Tool

`mcp__shellicar__exec` replaces the Bash tool entirely. When enabled, Bash is disallowed — use this tool for all command execution. Programs are spawned directly via `child_process.spawn()` — no shell is involved.

## Quick Reference

**Single command:**
```json
{
  "description": "Check git status",
  "steps": [{ "type": "command", "program": "git", "args": ["status"] }]
}
```

**Multi-step (bail on error — default):**
```json
{
  "description": "Build then test",
  "steps": [
    { "type": "command", "program": "pnpm", "args": ["build"] },
    { "type": "command", "program": "pnpm", "args": ["test"] }
  ]
}
```

**Pipeline:**
```json
{
  "description": "Count TODOs in src",
  "steps": [{
    "type": "pipeline",
    "commands": [
      { "program": "grep", "args": ["-r", "TODO", "src/"] },
      { "program": "wc", "args": ["-l"] }
    ]
  }]
}
```

**stdin (replaces heredocs):**
```json
{
  "description": "Run inline node script",
  "steps": [{ "type": "command", "program": "node", "args": [], "stdin": "console.log(process.version)" }]
}
```

**Redirect output:**
```json
{
  "description": "Save curl response to file",
  "steps": [{ "type": "command", "program": "curl", "args": ["-s", "https://api.example.com/data"], "redirect": { "path": "/tmp/response.json" } }]
}
```

**Env vars:**
```json
{
  "description": "Run with NODE_ENV=production",
  "steps": [{ "type": "command", "program": "node", "args": ["app.js"], "env": { "NODE_ENV": "production" } }]
}
```

**Working directory override:**
```json
{
  "description": "Build package in subdir",
  "steps": [{ "type": "command", "program": "pnpm", "args": ["build"], "cwd": "/home/stephen/project/packages/api" }]
}
```

**Background process:**
```json
{
  "description": "Start dev server",
  "background": true,
  "steps": [{ "type": "command", "program": "pnpm", "args": ["dev"] }]
}
```

## Bash → Exec Translation

| Bash pattern | Exec equivalent |
|---|---|
| `git status` | `{ program: "git", args: ["status"] }` |
| `pnpm build && pnpm test` | Two steps, `chaining: "bail_on_error"` (default) |
| `pnpm build; pnpm test` | Two steps, `chaining: "sequential"` |
| `grep -r TODO src/ \| wc -l` | `type: "pipeline"` with two commands |
| `cat <<EOF \| node` | Single command with `stdin` field |
| `curl ... > /tmp/out.json` | Command with `redirect: { path: "/tmp/out.json" }` |
| `NODE_ENV=prod node app.js` | Command with `env: { "NODE_ENV": "prod" }` |
| `cd subdir && pnpm build` | Command with `cwd: "/absolute/path/to/subdir"` |
| `command &` | Top-level `background: true` |
| `~/.claude/skills/foo/scripts/bar.sh` | `program: "/home/stephen/.claude/skills/foo/scripts/bar.sh"` — use absolute path, no tilde |
| `echo "text" > file` | Use the Write tool instead |

**Chaining modes:**

| Mode | Behaviour |
|---|---|
| `bail_on_error` | Stop on first non-zero exit — default, equivalent to `&&` |
| `sequential` | Run all steps regardless of exit code, equivalent to `;` |
| `independent` | Run all steps, report each result separately |

## Blocked Operations

Built-in validation blocks these before execution:

- `rm`, `rmdir`, `mkfs`, `dd`, `shred` — destructive filesystem
- `xargs` — arbitrary piped execution
- `sed -i` / `sed --in-place` — in-place file modification (use Edit tool)
- `git rm` — file removal from index
- `git checkout` — use `git switch` for branch switching
- `git reset` — ask the Supreme Commander
- `git push -f` / `--force*` — force pushes (always banned)

## Gotchas

- **No shell expansion anywhere**: `~`, `$VAR`, `*.ts` globs are NOT expanded in `program`, `args[]`, or `cwd`. Use absolute paths. Use `find` or a pipeline for globs. Invalid `cwd` causes a misleading "Command not found" error rather than a directory error.
- **No `cd` persistence**: There is no shell session between steps. Use `cwd` per-step.
- **ENOENT = exit 127**: Program not found on `$PATH` returns exit code 127.
- **Pipeline stderr**: Only stdout is piped between pipeline commands. Each command's stderr is collected separately in output.
- **No chaining syntax**: `&&`, `;`, `||`, `$()`, backticks — none of these work. Use `steps[]` with appropriate `chaining` mode.
