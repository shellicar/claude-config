#!/bin/sh
# Gather all git state needed for a commit decision
# Outputs structured sections that Claude can parse in one read
#
# Usage: git-commit-info.sh
#
# Platform and project are auto-detected from git remote URL:
#   GitHub:     https://github.com/<owner>/<repo>.git
#   Azure DevOps: https://<org>@dev.azure.com/<org>/<project>/_git/<repo>
#
# Sections output:
#   BRANCH        - current branch name
#   MERGED_PR     - whether a merged PR exists for this branch
#   STAGED_STAT   - staged changes summary (diffstat)
#   STATUS        - full git status output
#   RECENT_LOG    - recent commit messages for style reference

set -e

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
    # URL format: https://<org>@dev.azure.com/<org>/<project>/_git/<repo>
    # Extract project: strip up to 3rd slash after dev.azure.com/, then take segment before /_git
    PROJECT=$(echo "$REMOTE_URL" | sed 's|.*dev\.azure\.com/[^/]*/||' | sed 's|/_git/.*||')
    if [ -z "$PROJECT" ]; then
      echo "❌ Could not extract project name from remote URL: $REMOTE_URL" >&2
      exit 1
    fi
    ;;
  *)
    echo "❌ Unrecognised remote URL format: $REMOTE_URL" >&2
    exit 1
    ;;
esac

echo "Platform: $PLATFORM"
if [ -n "$PROJECT" ]; then
  echo "Project: $PROJECT"
fi

section() {
  printf '\n--- %s ---\n' "$1"
}

# Branch
section "BRANCH"
BRANCH=$(git branch --show-current)
echo "$BRANCH"

# Merged PR check
section "MERGED_PR"
if [ "$PLATFORM" = "github" ]; then
  gh pr list --head "$BRANCH" --state merged --json number,title 2>/dev/null || echo "[]"
elif [ "$PLATFORM" = "azure-devops" ]; then
  az repos pr list --source-branch "$BRANCH" --status completed --project "$PROJECT" -o json 2>/dev/null || echo "[]"
fi

# Staged changes summary
section "STAGED_STAT"
git diff --staged --stat 2>/dev/null || echo "(no staged changes)"

# Full status
section "STATUS"
git status

# Recent commits for style reference
section "RECENT_LOG"
git log --oneline -5 2>/dev/null || echo "(no commits)"
