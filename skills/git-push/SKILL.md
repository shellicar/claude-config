---
name: git-push
description: "Push commits to remote with secret and PII scanning.\nTRIGGER when: pushing code, after committing, before creating a PR, or asked to push.\nDO NOT TRIGGER when: reading git status, exploring history, or non-push git operations."
---

# Git Push Workflow

**Scope:** Git CLI commands for pushing, secret scanning gates, and divergence checks. Convention-specific rules live in convention skills.

Push local commits to the remote with mandatory secret and PII scanning.

## Working Directory

Always `cd` to the project directory first, then use bare `git` commands (e.g., `git push`, not `git -C /path push`). This ensures commands match auto-approve patterns in the user's permission settings.

## Steps

### 1. Gather git state

Run the gather script to collect push state in one call:

```bash
~/.claude/skills/git-push/scripts/git-push-info.sh
```

The script calls `detect-convention` internally and outputs `Convention: <name>` in the header.

The script outputs structured sections: `BRANCH`, `PROTECTED_BRANCHES`, `HAS_UPSTREAM`, `COMMITS_TO_PUSH`, `DIVERGENCE`, `DIFFSTAT`.

After running the script, load the `<convention>-conventions` skill if `Convention:` is present in the output. If not present, proceed without convention-specific rules.

### 2. Analyse the gathered state

From the script output, check the following — stop and inform the Supreme Commander if any fail:

- **Branch protection** *(check this first)*: If `BRANCH` appears in `PROTECTED_BRANCHES` (and `PROTECTED_BRANCHES` is not `none`), **STOP immediately** — direct pushes to this branch are not allowed. Inform the Supreme Commander and offer to create a branch or open a PR.
- **No commits to push**: If `COMMITS_TO_PUSH` is empty, inform the Supreme Commander and stop.
- **Divergence**: If `DIVERGENCE` shows behind count > 0, the branch has diverged — STOP and inform the Supreme Commander, as this may require manual intervention (rebase, merge, or force push).

### 3. Triage files for secret scanning

Review the `DIFFSTAT` section. For each commit, identify files that need scanning vs files that can be skipped:

**Skip** (no secret risk):
- Lock files (`*.lock`, `package-lock.json`, `pnpm-lock.yaml`)
- Minified/bundled files (`*.min.js`, `*.min.css`, `dist/*`)
- Binary files (images, fonts, archives)
- Large generated files (migration SQL dumps, test fixtures > 1000 lines)

**Scan** (potential secret risk):
- Source code, config files, scripts, environment files
- Any file that could contain credentials, API keys, tokens, or PII

### 4. Secret and PII scanning

Load the `secret-scanning` skill. Fetch diffs only for commits/files that need scanning:

```bash
~/.claude/skills/git-push/scripts/git-push-diffs.sh <hash> [<hash> ...]
```

Use `--exclude <glob>` to skip files identified in step 4:

```bash
~/.claude/skills/git-push/scripts/git-push-diffs.sh --exclude '*.lock' --exclude 'dist/*' <hash> [<hash> ...]
```

Apply the pattern tables and Finding Disposition Process to each commit's diff.

**Important**: A secret added in one commit and removed in a later commit is still in the pushed history. Each commit must be clean.

Do NOT silently push code containing matches. Present findings and wait for confirmation from the Supreme Commander before proceeding.

### 5. Push

```bash
git push
```

For new branches (no upstream):

```bash
git push -u origin <branch-name>
```

### 6. Verify and offer PR

```bash
git log @{u}..HEAD --oneline
```

Should show no commits (all pushed). If commits remain, report the issue.

Use `AskUserQuestion` with options like "Create PR" and "Skip". If the Supreme Commander requests a PR, invoke the appropriate skill:
- **GitHub conventions** → `github-pr`
- **Azure DevOps conventions** → `azure-devops-repos`
- **No convention** → infer from remote URL (`github.com` → `github-pr`, `dev.azure.com` → `azure-devops-repos`)
