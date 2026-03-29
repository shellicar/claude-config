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
#   open_pr           - array of open PRs for this branch [{id, title}]
#   merged_pr         - array of merged PRs for this branch [{id, title}]
#   has_upstream      - boolean: whether branch has a tracking remote
#   upstream          - upstream branch name (null if none)
#   upstream_status   - "active" (tracking ref exists), "gone" (deleted on remote), "none" (never set)
#   commits_to_push   - array of local commits [{hash, message}]
#   divergence        - {behind, ahead} counts relative to upstream
#
# Exit codes:
#   0 - success
#   2 - upstream is gone (remote branch was deleted) — stderr has error message
#   3 - branch was already merged — stderr has error message

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# Detect platform from remote URL
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
    ;;
esac

BRANCH=$(git branch --show-current)

# Platform-specific info (protected branches, PRs)
PLATFORM_JSON='{"protected_branches":[],"open_pr":[],"merged_pr":[]}'
if [ "$PLATFORM" = "github" ]; then
  PLATFORM_JSON=$("$SCRIPT_DIR/git-push-info-github.sh" "$BRANCH" 2>/dev/null) || PLATFORM_JSON='{"protected_branches":[],"open_pr":[],"merged_pr":[]}'
elif [ "$PLATFORM" = "azure-devops" ]; then
  ORG=$(echo "$REMOTE_URL" | sed 's|.*dev\.azure\.com/||' | cut -d'/' -f1)
  PLATFORM_JSON=$("$SCRIPT_DIR/git-push-info-ado.sh" "$BRANCH" "$ORG" "$PROJECT" 2>/dev/null) || PLATFORM_JSON='{"protected_branches":[],"open_pr":[],"merged_pr":[]}'
fi

# Prune stale remote refs so upstream:track reflects reality
git fetch -p origin 2>/dev/null || true

# Exit if branch was already merged
MERGED_PR_COUNT=$(printf '%s' "$PLATFORM_JSON" | jq '.merged_pr | length')
if [ "$MERGED_PR_COUNT" -gt 0 ]; then
  MERGED_TITLE=$(printf '%s' "$PLATFORM_JSON" | jq -r '.merged_pr[0].title')
  printf 'error: this branch was already merged (PR: "%s").\n' "$MERGED_TITLE" >&2
  printf 'Rebase onto main before pushing new work from this branch.\n' >&2
  exit 3
fi

# Upstream detection: none / active / gone
# Use for-each-ref to get upstream info (works even when upstream is gone)
HAS_UPSTREAM=false
UPSTREAM=""
UPSTREAM_STATUS="none"
UPSTREAM_REF=$(git for-each-ref --format='%(upstream)' "refs/heads/$BRANCH" 2>/dev/null || true)
UPSTREAM_TRACK=$(git for-each-ref --format='%(upstream:track)' "refs/heads/$BRANCH" 2>/dev/null || true)

if [ -n "$UPSTREAM_REF" ]; then
  HAS_UPSTREAM=true
  # Convert refs/remotes/origin/branch to origin/branch
  UPSTREAM=$(echo "$UPSTREAM_REF" | sed 's|^refs/remotes/||')
  case "$UPSTREAM_TRACK" in
    *gone*)
      UPSTREAM_STATUS="gone"
      printf 'error: upstream branch "%s" is gone (deleted on remote).\n' "$UPSTREAM" >&2
      printf 'The local branch still tracks it, but the remote ref no longer exists.\n' >&2
      printf 'Action: delete the local branch or reset its upstream.\n' >&2
      exit 2
      ;;
    *)
      UPSTREAM_STATUS="active"
      ;;
  esac
fi

# Determine commit range base
# If upstream exists and is active, use @{u}
# Otherwise, use git-find-fork-point.sh to find the nearest remote ancestor
COMMIT_BASE=""
if [ "$HAS_UPSTREAM" = true ]; then
  COMMIT_BASE="@{u}"
else
  FORK_SCRIPT="$SCRIPT_DIR/git-find-fork-point.sh"
  if [ -f "$FORK_SCRIPT" ]; then
    FORK_JSON=$("$FORK_SCRIPT" 2>/dev/null || true)
    if [ -n "$FORK_JSON" ]; then
      FORK_HASH=$(echo "$FORK_JSON" | jq -r '.fork_point // empty' 2>/dev/null || true)
      if [ -n "$FORK_HASH" ]; then
        COMMIT_BASE=$(git rev-parse "$FORK_HASH" 2>/dev/null || true)
      fi
    fi
  fi
fi

# Commits to push (structured: hash + message)
COMMITS_TO_PUSH='[]'
if [ -n "$COMMIT_BASE" ]; then
  COMMITS_TO_PUSH=$(git log --format='%h%x00%s' "${COMMIT_BASE}..HEAD" \
    | jq -Rs '[split("\n")[] | select(. != "") | split("\u0000") | {hash: .[0], message: .[1]}]' || echo '[]')
fi

# Divergence (behind/ahead)
DIVERGENCE_BEHIND=0
DIVERGENCE_AHEAD=0
if [ "$HAS_UPSTREAM" = true ]; then
  DIVERGENCE=$(git rev-list --left-right --count @{u}...HEAD)
  DIVERGENCE_BEHIND=$(echo "$DIVERGENCE" | cut -f1)
  DIVERGENCE_AHEAD=$(echo "$DIVERGENCE" | cut -f2)
fi

# Build JSON
jq -n \
  --arg platform "$PLATFORM" \
  --arg project "$PROJECT" \
  --arg convention "$CONVENTION" \
  --arg branch "$BRANCH" \
  --argjson platform_info "$PLATFORM_JSON" \
  --arg has_upstream "$HAS_UPSTREAM" \
  --arg upstream "$UPSTREAM" \
  --arg upstream_status "$UPSTREAM_STATUS" \
  --argjson commits_to_push "$COMMITS_TO_PUSH" \
  --arg divergence_behind "$DIVERGENCE_BEHIND" \
  --arg divergence_ahead "$DIVERGENCE_AHEAD" \
  '{
    platform: $platform,
    project: (if $project == "" then null else $project end),
    convention: (if $convention == "" then null else $convention end),
    branch: $branch,
    protected_branches: $platform_info.protected_branches,
    open_pr: $platform_info.open_pr,
    merged_pr: $platform_info.merged_pr,
    has_upstream: ($has_upstream | fromjson? // false),
    upstream: (if $upstream == "" then null else $upstream end),
    upstream_status: $upstream_status,
    commits_to_push: $commits_to_push,
    divergence: {behind: ($divergence_behind | fromjson? // 0), ahead: ($divergence_ahead | fromjson? // 0)}
  }'
