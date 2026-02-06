# claude-config

> Personal Claude Code configuration with custom skills and protocols.

## Setup

```sh
nvm install
corepack enable
pnpm install
```

## Skills

### Protocol Skills

- **teapot-protocol** - Compliance checking with brewing cycle
- **commander-protocol** - Chain of command and interaction guidelines

### Coding Skills

- **typescript-standards** - TypeScript coding standards, banned types, and testing patterns
- **tdd** - Test-Driven Development workflow enforcement
- **shell-scripting** - POSIX-compliant shell scripting guidelines
- **cli-tools** - Conventions for running CLI commands via the Bash tool

### Git Workflow Skills

- **git-commit** - Create commits with concise messages (`/git-commit`)
- **github-pr** - Create or update pull requests (`/github-pr`)
- **git-cleanup** - Analyze and clean up local branches (`/git-cleanup`)
- **maintenance-release** - Security fixes and dependency updates (`/maintenance-release`)
- **github-version** - Version bumping and CHANGELOG updates
- **github-release** - Create GitHub releases to trigger npm publish

### Convention Skills

Detected automatically based on remote URL and working directory:

- **shellicar-conventions** - Personal GitHub projects
- **shellicar-oss-conventions** - Published @shellicar npm packages
- **shellicar-config-conventions** - Personal config repos (no PRs, direct to main)
- **eagers-conventions** - Eagers Automotive (Azure DevOps)
- **hopeventures-conventions** - Hope Ventures (Azure DevOps)
- **flightrac-conventions** - Flightrac (Azure DevOps)

### Azure DevOps Skills

- **azure-devops** - CLI reference (redirects to specific skills)
- **azure-devops-boards** - Work items, hierarchy, and migrations
- **azure-devops-repos** - PRs and merge workflows
- **azure-devops-pipelines** - Pipeline runs and configuration
- **ado-backlog-columns** - Consistent backlog column options

### Utility Skills

- **skill-management** - Creating and maintaining skills

### Installed Skills

Installed from [skills.sh](https://skills.sh/) via `pnpm skills add`:

- **skill-creator** - Guide for creating effective skills
- **find-skills** - Discover and install skills
