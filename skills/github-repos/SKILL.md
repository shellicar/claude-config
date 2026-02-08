---
name: github-repos
description: GitHub repository settings and ruleset configuration. Use when configuring repo features (wiki, issues, projects), merge settings (auto-merge, delete branch on merge), or branch rulesets. Also use when auditing or verifying repo configuration against convention standards.
user-invocable: true
---

# GitHub Repository Configuration

Configure GitHub repo settings and branch rulesets. Convention skills define WHAT settings a repo should have; this skill defines HOW to apply them.

## Workflow

1. Detect convention via `~/.claude/skills/github-pr/scripts/detect-convention.sh`
2. Load the convention skill to get desired settings
3. Fetch current settings and compare
4. Apply changes and verify

## Repo Settings

### Check Current Settings

```bash
gh repo view --json hasIssuesEnabled,hasWikiEnabled,hasProjectsEnabled,hasDiscussionsEnabled
gh api repos/{owner}/{repo} --jq '{allow_auto_merge, delete_branch_on_merge}'
```

### Apply Settings

```bash
gh repo edit --enable-wiki=false
gh repo edit --enable-issues=true
gh repo edit --enable-projects=false
gh repo edit --enable-discussions=false
gh repo edit --enable-auto-merge --delete-branch-on-merge=true
gh repo edit --default-branch main
```

## Rulesets

### Check Existing

```bash
gh api repos/{owner}/{repo}/rulesets --jq '.[] | {id, name, enforcement}'
gh api repos/{owner}/{repo}/rulesets/{id}  # Full details
```

### Create Ruleset

```bash
gh api repos/{owner}/{repo}/rulesets --method POST --input - <<'EOF'
{ ... }
EOF
```

### Update Ruleset

```bash
gh api repos/{owner}/{repo}/rulesets/{id} --method PUT --input - <<'EOF'
{ ... }
EOF
```

### Standard Ruleset JSON

The convention skill defines which rules to include. Build the JSON from:

```json
{
  "name": "main",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}
  },
  "rules": []
}
```

### Available Rule Types

| Rule | JSON | Purpose |
|------|------|---------|
| deletion | `{"type": "deletion"}` | Prevent branch deletion |
| non_fast_forward | `{"type": "non_fast_forward"}` | Prevent force push |
| creation | `{"type": "creation"}` | Prevent direct branch creation |
| code_scanning | See below | Require CodeQL checks |
| pull_request | See below | Require PRs with merge method control |
| required_status_checks | `{"type": "required_status_checks"}` | Require CI checks (omit if no CI) |

#### code_scanning

```json
{"type": "code_scanning", "parameters": {
  "code_scanning_tools": [{"tool": "CodeQL", "security_alerts_threshold": "high_or_higher", "alerts_threshold": "errors"}]
}}
```

#### pull_request

```json
{"type": "pull_request", "parameters": {
  "required_approving_review_count": 0,
  "dismiss_stale_reviews_on_push": false,
  "required_reviewers": [],
  "require_code_owner_review": false,
  "require_last_push_approval": false,
  "required_review_thread_resolution": false,
  "allowed_merge_methods": ["squash"]
}}
```

### Verify

```bash
gh repo view --json hasIssuesEnabled,hasWikiEnabled,hasProjectsEnabled,hasDiscussionsEnabled
gh api repos/{owner}/{repo} --jq '{allow_auto_merge, delete_branch_on_merge}'
gh api repos/{owner}/{repo}/rulesets --jq '.[] | {name, enforcement}'
```

### Bulk Management

For @shellicar repos, use ecosystem scripts:

```bash
~/repos/@shellicar/ecosystem/scripts/sync-rulesets.sh      # Dry-run
~/repos/@shellicar/ecosystem/scripts/sync-rulesets.sh -d    # Apply
```
