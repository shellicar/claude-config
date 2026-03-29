#!/bin/sh
# Gather all git state needed for a commit decision
# Outputs JSON that Claude can parse
#
# Usage: git-commit-info.sh
#
# Platform and project are auto-detected from git remote URL:
#   GitHub:     https://github.com/<owner>/<repo>.git
#   Azure DevOps: https://<org>@dev.azure.com/<org>/<project>/_git/<repo>
#
# Output fields:
#   platform          - "github" or "azure-devops"
#   project           - Azure DevOps project name (null for GitHub)
#   convention        - detected convention name (null if none)
#   branch            - current branch name
#   protected_branches - array of protected branch names
#   open_pr           - array of open PRs for this branch
#   merged_pr         - array of merged PRs for this branch
#   staged_files      - staged files with insertion/deletion counts (array)
#   status            - {unstaged: [{path, change}], untracked: [path]}
#   recent_log        - recent commit messages (array of strings)

set -e

# Verify git identity is configured before proceeding
GIT_NAME=$(git config user.name 2>/dev/null || true)
GIT_EMAIL=$(git config user.email 2>/dev/null || true)
if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
  printf '{"error":"Git identity not fully configured (name=%s, email=%s). Stop and confirm with user before proceeding."}\n' "$GIT_NAME" "$GIT_EMAIL" >&2
  exit 1
fi

# Detect convention name
DETECT_SCRIPT="$HOME/.claude/skills/detect-convention/scripts/detect-convention.sh"
CONVENTION=""
if [ -f "$DETECT_SCRIPT" ]; then
  CONVENTION=$("$DETECT_SCRIPT" 2>/dev/null | sed -n '1p' || echo "")
fi

# Auto-detect platform and project from git remote
REMOTE_URL=$(git remote get-url origin)
PLATFORM=""
PROJECT=""

case "$REMOTE_URL" in
  *github.com*)
    PLATFORM="github"
    ;;
  *dev.azure.com*)
    PLATFORM="azure-devops"
    PROJECT=$(echo "$REMOTE_URL" | sed 's|.*dev\.azure\.com/[^/]*/||' | sed 's|/_git/.*||')
    if [ -z "$PROJECT" ]; then
      printf '{"error":"Could not extract project name from remote URL: %s"}\n' "$REMOTE_URL" >&2
      exit 1
    fi
    ;;
  *)
    printf '{"error":"Unrecognised remote URL format: %s"}\n' "$REMOTE_URL" >&2
    exit 1
    ;;
esac

# Detect protected branches (JSON array)
PROTECTED_BRANCHES='[]'
if [ "$PLATFORM" = "github" ]; then
  PROTECTED_BRANCHES=$(gh api repos/{owner}/{repo}/branches \
    --jq '[.[] | select(.protected) | .name]' 2>/dev/null) || PROTECTED_BRANCHES='[]'
elif [ "$PLATFORM" = "azure-devops" ]; then
  ORG=$(echo "$REMOTE_URL" | sed 's|.*dev\.azure\.com/||' | cut -d'/' -f1)
  PROTECTED_BRANCHES=$(az rest --method GET \
    --url "https://dev.azure.com/$ORG/$PROJECT/_apis/policy/configurations?api-version=7.1" \
    --resource 499b84ac-1321-427f-aa17-267ca6975798 2>/dev/null \
    | jq '[.value[] | .settings.scope[]? | .refName // empty | select(startswith("refs/heads/")) | ltrimstr("refs/heads/")] | unique' 2>/dev/null || echo '[]')
fi

BRANCH=$(git branch --show-current)

# Open PR
OPEN_PR='[]'
if [ "$PLATFORM" = "github" ]; then
  OPEN_PR=$(gh pr list --head "$BRANCH" --state open --json number,title,url 2>/dev/null) || OPEN_PR='[]'
elif [ "$PLATFORM" = "azure-devops" ]; then
  OPEN_PR=$(az repos pr list --source-branch "$BRANCH" --status active --project "$PROJECT" -o json 2>/dev/null \
    | jq '[.[] | {id: .pullRequestId, title: .title}]' 2>/dev/null) || OPEN_PR='[]'
fi

# Merged PR
MERGED_PR='[]'
if [ "$PLATFORM" = "github" ]; then
  MERGED_PR=$(gh pr list --head "$BRANCH" --state merged --json number,title 2>/dev/null) || MERGED_PR='[]'
elif [ "$PLATFORM" = "azure-devops" ]; then
  MERGED_PR=$(az repos pr list --source-branch "$BRANCH" --status completed --project "$PROJECT" -o json 2>/dev/null \
    | jq '[.[] | {id: .pullRequestId, title: .title}]' 2>/dev/null) || MERGED_PR='[]'
fi

# Staged files (numstat: insertions, deletions, path — binary files use null)
STAGED_FILES=$(git diff --staged --numstat 2>/dev/null \
  | jq -Rs '[split("\n")[] | select(. != "") | split("\t") | {
      insertions: (.[0] | if . == "-" then null else tonumber end),
      deletions:  (.[1] | if . == "-" then null else tonumber end),
      path: .[2]
    }]' || echo '[]')
# Working tree status (porcelain: grouped by change type)
STATUS=$(git status --porcelain 2>/dev/null \
  | jq -Rs '[split("\n")[] | select(. != "")] | {
      modified:  [.[] | select(.[0:2] != "??" and .[1:2] == "M") | .[3:]],
      deleted:   [.[] | select(.[0:2] != "??" and .[1:2] == "D") | .[3:]],
      added:     [.[] | select(.[0:2] != "??" and .[1:2] == "A") | .[3:]],
      untracked: [.[] | select(.[0:2] == "??") | .[3:]]
    }' || echo '{"modified":[],"deleted":[],"added":[],"untracked":[]}')
RECENT_LOG=$(git log --oneline -5 2>/dev/null | jq -Rs 'split("\n") | map(select(. != ""))' || echo '[]')

# Build JSON
jq -n \
  --arg platform "$PLATFORM" \
  --arg project "$PROJECT" \
  --arg convention "$CONVENTION" \
  --arg branch "$BRANCH" \
  --arg protected_branches "$PROTECTED_BRANCHES" \
  --arg open_pr "$OPEN_PR" \
  --arg merged_pr "$MERGED_PR" \
  --arg staged_files "$STAGED_FILES" \
  --arg status "$STATUS" \
  --arg recent_log "$RECENT_LOG" \
  '{
    platform: $platform,
    project: (if $project == "" then null else $project end),
    convention: (if $convention == "" then null else $convention end),
    branch: $branch,
    protected_branches: ($protected_branches | fromjson? // []),
    open_pr: ($open_pr | fromjson? // []),
    merged_pr: ($merged_pr | fromjson? // []),
    staged_files: ($staged_files | fromjson? // []),
    status: ($status | fromjson? // {modified:[],deleted:[],added:[],untracked:[]}),
    recent_log: ($recent_log | fromjson? // [])
  }'
