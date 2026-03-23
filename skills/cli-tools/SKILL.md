---
name: cli-tools
description: "DEPRECATED. Replaced by mcp-shellicar.\nTRIGGER never."
user-invocable: false
metadata:
  category: foundational
  deprecated: mcp-shellicar
---

> **DEPRECATED**: Replaced by `mcp-shellicar`. Do not load this skill.

# CLI Tool Conventions

**Scope:** How to run CLI commands via the Bash tool — working directory, blocked tools, banned commands, sequential execution, and auto-approve patterns. Security model and threat analysis live in auto-approve-security.

Guidelines for how to execute commands via the Bash tool.

## Working Directory

The working directory set via `cd` **persists between separate Bash tool calls**. Use `cd` to change directory once, then run subsequent commands without path prefixes or chaining. You do NOT need to `cd` in every command.

## Blocked Tools

Do NOT use these tools via Bash:

- `python` / `python3` — use dedicated tools or native shell instead
- `jq` — construct and parse JSON using the Write/Read tools

Construct all JSON directly using the Write tool. Reference saved files using the CLI tool's file input syntax instead of inline JSON or piping:
  - `az rest --body @file.json`
  - `curl -d @file.json`
  - `gh api --input file.json`

## Temp Files

When saving data to temp files:

- Use **meaningful names** that describe the contents, not generic names like `body.json` or `data.json`
- Examples:
  - `/tmp/ado-columns-with-parent.json` — column config including Parent column
  - `/tmp/ado-columns-without-parent.json` — column config without Parent column
  - `/tmp/ado-columns-body.json` — combined PATCH body for all categories

## Command Comments

Before each command, add a **comment explaining what it does**:

```bash
# Portfolio Team - Initiative: without-parent, Epic/Feature/PBI: with-parent
echo '{"org":"...", "project":"...", "method":"PATCH", "path":"..."}' | ~/.claude/skills/azure-devops/scripts/ado-rest.sh
```

This is especially important when running the same command template against multiple targets (teams, resources, etc.).

## Banned Commands

The following commands are banned to prevent accidental data loss or destructive operations:

- `rm` — use `unlink` for symlinks; prefer dedicated Read/Write/Edit tools for file operations
- `sed` — use the Edit tool instead
- `xargs` — too easy to cause unintended side effects
- `git rm` — ask the user to handle file removal
- `git checkout` — use `git switch` for branch switching
- `git reset` — ask the user to handle resets
- `git push --force` / `-f` — never force push
- `*.exe` — any `.exe` binary; blocks WSL2 escape vectors (`cmd.exe`, `powershell.exe`, `pwsh.exe`, etc.)

## Auto-Approved Commands

Some commands are auto-approved via `settings.json` (e.g., `git show`, `git log`, `git diff`). To benefit from this:

- Use the **simple form** of commands that matches the approved pattern — don't add flags like `-C <path>` before the subcommand
- If you need to run a command in a different directory, `cd` there first or rely on your working directory rather than using path flags
- Example: use `git show <hash>` (matches `Bash(git show:*)`), not `git -C /some/path show <hash>` (won't match)

This avoids unnecessary permission prompts and keeps auto-approve patterns narrow.

## Sequential Commands

The PreToolUse hook blocks `&&`, `;`, and `||`. To run multiple commands sequentially, use **newlines** in a single Bash call:

```bash
cd /some/directory
. ./setup.sh
./run-something.sh
```

This works because each line runs in the same shell session, preserving environment variables and working directory. Use this instead of `&&` chaining.

If you need fail-fast behaviour (equivalent to `&&` chaining), use `set -e`:

```bash
set -e
git show --stat HEAD
pnpm dev:deploy:ciam
```

`set -e` stops execution on the first failure, same as `&&` but more readable.

## Command Descriptions

Always provide a clear `description` parameter when using the Bash tool, so the user can understand each command at a glance.

## Security Model

For the zero-trust auto-approve security model — threat analysis, exploit chains, tested vectors, and the auto-approve checklist — see the `auto-approve-security` skill.
