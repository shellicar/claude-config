#!/bin/sh
set -e

# Verify git identity is configured before proceeding
GIT_NAME=$(git config user.name 2>/dev/null || true)
GIT_EMAIL=$(git config user.email 2>/dev/null || true)
if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
  printf '{"error":"Git identity not fully configured (name=%s, email=%s). Stop and confirm with user before proceeding."}\n' "$GIT_NAME" "$GIT_EMAIL" >&2
  exit 1
fi

# github-pr-info.sh - Gather all PR-related state in one call
# Outputs JSON that Claude can parse
#
# Output fields:
#   convention     - detected convention name (null if none)
#   branch         - current branch name
#   default_branch - default branch (e.g. main)
#   merged_pr      - array of merged PRs for this branch
#   existing_pr    - open PR details object (null if none)
#   ancestor       - merge base branch (epic branch or default branch)
#   commits        - array of commits since ancestor (oneline strings)
#   milestones     - array of repo milestones
#   diffstat       - file-level change summary (string)

# Ensure we're running from the git root regardless of caller's cwd
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo '{"error":"not in a git repository"}' >&2
  exit 1
}
cd "$GIT_ROOT"

# Detect convention (name, default branch, protected branches)
DETECT_SCRIPT="$HOME/.claude/skills/detect-convention/scripts/detect-convention.sh"
CONVENTION=""
if [ -f "$DETECT_SCRIPT" ]; then
  CONVENTION=$("$DETECT_SCRIPT" 2>/dev/null | sed -n '1p' || echo "")
fi

# Detect default branch
DEFAULT=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
DEFAULT=${DEFAULT:-main}

BRANCH=$(git branch --show-current)

# Merged PR
MERGED_PR='[]'
if [ "$BRANCH" != "$DEFAULT" ]; then
  MERGED_PR=$(gh pr list --head "$BRANCH" --state merged --json number,title 2>/dev/null || echo '[]')
fi

# Existing (open) PR — rich query
EXISTING_PR='null'
if [ "$BRANCH" != "$DEFAULT" ]; then
  EXISTING_PR=$(gh pr list --head "$BRANCH" --state open \
    --json number,title,url,isDraft,autoMergeRequest,mergeStateStatus,mergeable,reviewDecision,reviewRequests,milestone,labels,statusCheckRollup \
    --jq 'if length > 0 then .[0] | {number,title,url,isDraft,mergeStateStatus,mergeable,reviewDecision,autoMergeRequest:.autoMergeRequest.mergeMethod,reviewRequests:[.reviewRequests[].login],milestone:.milestone.title,labels:[.labels[].name],checks:[.statusCheckRollup[]|{name,status,conclusion}]} else null end' \
    2>/dev/null || echo 'null')
fi

# Ancestor detection
MERGE_BASE=$(git merge-base HEAD "origin/$DEFAULT" 2>/dev/null || true)
ANCESTOR="origin/$DEFAULT"
if [ -n "$MERGE_BASE" ]; then
  EPIC=$(git branch -r --contains "$MERGE_BASE" 2>/dev/null | grep "epic/" | head -1 | tr -d ' ')
  if [ -n "$EPIC" ]; then
    ANCESTOR="$EPIC"
  fi
fi

# Commits
COMMITS=$(git log --oneline "$ANCESTOR..HEAD" 2>/dev/null | jq -Rs 'split("\n") | map(select(. != ""))' || echo '[]')

# Milestones
MILESTONES=$(gh api repos/{owner}/{repo}/milestones --method GET -f state=all \
  --jq '[.[] | {number, title, state, open_issues, closed_issues}]' 2>/dev/null || echo '[]')

# Changed files (numstat: binary files use null for counts)
DIFFSTAT=$(git diff "$ANCESTOR...HEAD" --numstat 2>/dev/null \
  | jq -Rs '[split("\n")[] | select(. != "") | split("\t") | {
      insertions: (.[0] | if . == "-" then null else tonumber end),
      deletions:  (.[1] | if . == "-" then null else tonumber end),
      path: .[2]
    }]' || echo '[]')

# Build JSON
jq -n \
  --arg convention "$CONVENTION" \
  --arg branch "$BRANCH" \
  --arg default_branch "$DEFAULT" \
  --arg merged_pr "$MERGED_PR" \
  --arg existing_pr "$EXISTING_PR" \
  --arg ancestor "$ANCESTOR" \
  --arg commits "$COMMITS" \
  --arg milestones "$MILESTONES" \
  --arg diffstat "$DIFFSTAT" \
  '{
    convention: (if $convention == "" then null else $convention end),
    branch: $branch,
    default_branch: $default_branch,
    merged_pr: ($merged_pr | fromjson? // []),
    existing_pr: ($existing_pr | fromjson? // null),
    ancestor: $ancestor,
    commits: ($commits | fromjson? // []),
    milestones: ($milestones | fromjson? // []),
    diffstat: ($diffstat | fromjson? // [])
  }'
