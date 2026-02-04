# claude-config

Personal Claude Code configuration with custom skills and protocols.

## Skills

### Protocol Skills

- **teapot-protocol** - Compliance checking system with brewing cycle
- **commander-protocol** - Chain of command and interaction guidelines

### Coding Skills

- **typescript** - TypeScript coding standards, banned types, and testing guidelines

### Git Workflow Skills

- **git-commit** - Create commits with concise messages (user-invocable: `/commit`)
- **git-pr** - Create or update pull requests with change summaries (user-invocable: `/pr`)

### Convention Skills

Detected automatically based on remote URL and working directory:

- **shellicar-conventions** - Personal GitHub projects (`~/repos/shellicar/`)
- **shellicar-oss-conventions** - Published @shellicar npm packages (`~/repos/@shellicar/`)
- **shellicar-config-conventions** - Personal config repos (`~/.claude`, `~/dotfiles`) - no PRs, direct to main
- **eagers-conventions** - Eagers Automotive projects (Azure DevOps)
- **hopeventures-conventions** - Hope Ventures projects (Azure DevOps)
- **flightrac-conventions** - Flightrac projects (Azure DevOps)

### Reference Skills

- **azure-devops** - CLI reference for Azure DevOps work items and PRs

### Utility Skills

- **keybindings-help** - Keyboard shortcut customization

## Convention Detection

The `detect-convention.sh` script automatically identifies which convention applies based on:

1. Git remote URL
2. Working directory path

Both must match for strict detection. If no convention matches, git workflows proceed without convention-specific rules.
