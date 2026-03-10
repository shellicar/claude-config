#!/bin/sh
# Gather all git state needed for a push decision
# Outputs JSON that Claude can parse
#
# Usage: git-push-info.sh
#
# Output fields:
#   platform          - "github" or "azure-devops"
#   project           - Azure DevOps project name (null for GitHub)
#   convention        - detected convention name (null if none)
#   branch            - current branch name
#   protected_branches - array of protected branch names
#   open_pr           - array of open PRs for this branch
#   merged_pr         - array of merged PRs for this branch
#   has_upstream      - boolean: whether branch has a tracking remote
#   upstream          - upstream branch name (null if none)
#   commits_to_push   - array of commits not yet pushed (oneline strings)
#   divergence        - {behind, ahead} counts relative to upstream
#   commits_detail    - per-commit file changes [{hash, message, files: [{insertions, deletions, path}]}]

set -e

# Detect convention name
DETECT_SCRIPT="$HOME/.claude/skills/detect-convention/scripts/detect-convention.sh"
CONVENTION=""
if [ -f "$DETECT_SCRIPT" ]; then
  CONVENTION=$("$DETECT_SCRIPT" 2>/dev/null | sed -n '1p' || echo "")
fi

# Detect platform and protected branches via API
REMOTE_URL=$(git remote get-url origin)
PLATFORM=""
PROJECT=""
PROTECTED_BRANCHES='[]'

case "$REMOTE_URL" in
  *github.com*)
    PLATFORM="github"
    PROTECTED_BRANCHES=$(gh api repos/{owner}/{repo}/branches \
      --jq '[.[] | select(.protected) | .name]' 2>/dev/null || echo '[]')
    ;;
  *dev.azure.com*)
    PLATFORM="azure-devops"
    ORG=$(echo "$REMOTE_URL" | sed 's|.*dev\.azure\.com/||' | cut -d'/' -f1)
    PROJECT=$(echo "$REMOTE_URL" | sed 's|.*dev\.azure\.com/[^/]*/||' | sed 's|/_git/.*||')
    PROTECTED_BRANCHES=$(az rest --method GET \
      --url "https://dev.azure.com/$ORG/$PROJECT/_apis/policy/configurations?api-version=7.1" \
      --resource 499b84ac-1321-427f-aa17-267ca6975798 2>/dev/null \
      | jq '[.value[] | .settings.scope[]? | .refName // empty | select(startswith("refs/heads/")) | ltrimstr("refs/heads/")] | unique' 2>/dev/null || echo '[]')
    ;;
esac

BRANCH=$(git branch --show-current)

# Open PR
OPEN_PR='[]'
if [ "$PLATFORM" = "github" ]; then
  OPEN_PR=$(gh pr list --head "$BRANCH" --state open --json number,title,url 2>/dev/null || echo '[]')
elif [ "$PLATFORM" = "azure-devops" ]; then
  OPEN_PR=$(az repos pr list --source-branch "$BRANCH" --status active --project "$PROJECT" -o json 2>/dev/null || echo '[]')
fi

# Merged PR
MERGED_PR='[]'
if [ "$PLATFORM" = "github" ]; then
  MERGED_PR=$(gh pr list --head "$BRANCH" --state merged --json number,title 2>/dev/null || echo '[]')
elif [ "$PLATFORM" = "azure-devops" ]; then
  MERGED_PR=$(az repos pr list --source-branch "$BRANCH" --status completed --project "$PROJECT" -o json 2>/dev/null || echo '[]')
fi

# Upstream detection
HAS_UPSTREAM=false
UPSTREAM=""
if git rev-parse --abbrev-ref "@{u}" >/dev/null 2>&1; then
  HAS_UPSTREAM=true
  UPSTREAM=$(git rev-parse --abbrev-ref "@{u}")
fi

# Commits to push
COMMITS_TO_PUSH='[]'
if [ "$HAS_UPSTREAM" = true ]; then
  COMMITS_TO_PUSH=$(git log @{u}..HEAD --oneline | jq -Rs 'split("\n") | map(select(. != ""))' || echo '[]')
else
  COMMITS_TO_PUSH=$(git log --oneline -10 | jq -Rs 'split("\n") | map(select(. != ""))' || echo '[]')
fi

# Divergence (behind/ahead)
DIVERGENCE_BEHIND=0
DIVERGENCE_AHEAD=0
if [ "$HAS_UPSTREAM" = true ]; then
  DIVERGENCE=$(git rev-list --left-right --count @{u}...HEAD)
  DIVERGENCE_BEHIND=$(echo "$DIVERGENCE" | cut -f1)
  DIVERGENCE_AHEAD=$(echo "$DIVERGENCE" | cut -f2)
fi

# Per-commit file changes (numstat: binary files use null for counts)
if [ "$HAS_UPSTREAM" = true ]; then
  HASHES=$(git log @{u}..HEAD --format="%H")
else
  HASHES=$(git log --format="%H" -10)
fi

COMMITS_DETAIL='[]'
if [ -n "$HASHES" ]; then
  COMMITS_DETAIL=$(echo "$HASHES" | while read -r hash; do
    HASH_SHORT=$(git log -1 --format='%h' "$hash")
    MSG=$(git log -1 --format='%s' "$hash")
    FILES=$(git diff-tree --no-commit-id -r --numstat "$hash" \
      | jq -Rs '[split("\n")[] | select(. != "") | split("\t") | {
          insertions: (.[0] | if . == "-" then null else tonumber end),
          deletions:  (.[1] | if . == "-" then null else tonumber end),
          path: .[2]
        }]' || echo '[]')
    jq -n --arg hash "$HASH_SHORT" --arg message "$MSG" --argjson files "$FILES" \
      '{hash: $hash, message: $message, files: $files}'
  done | jq -s '.' || echo '[]')
fi

# Build JSON
jq -n \
  --arg platform "$PLATFORM" \
  --arg project "$PROJECT" \
  --arg convention "$CONVENTION" \
  --arg branch "$BRANCH" \
  --argjson protected_branches "$PROTECTED_BRANCHES" \
  --argjson open_pr "$OPEN_PR" \
  --argjson merged_pr "$MERGED_PR" \
  --argjson has_upstream "$HAS_UPSTREAM" \
  --arg upstream "$UPSTREAM" \
  --argjson commits_to_push "$COMMITS_TO_PUSH" \
  --argjson divergence_behind "$DIVERGENCE_BEHIND" \
  --argjson divergence_ahead "$DIVERGENCE_AHEAD" \
  --argjson commits_detail "$COMMITS_DETAIL" \
  '{
    platform: $platform,
    project: (if $project == "" then null else $project end),
    convention: (if $convention == "" then null else $convention end),
    branch: $branch,
    protected_branches: $protected_branches,
    open_pr: $open_pr,
    merged_pr: $merged_pr,
    has_upstream: $has_upstream,
    upstream: (if $upstream == "" then null else $upstream end),
    commits_to_push: $commits_to_push,
    divergence: {behind: $divergence_behind, ahead: $divergence_ahead},
    commits_detail: $commits_detail
  }'
