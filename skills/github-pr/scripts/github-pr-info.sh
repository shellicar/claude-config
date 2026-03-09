#!/bin/sh
set -e

# github-pr-info.sh - Gather all PR-related state in one call
# Consolidates branch check, merged PR, ancestor detection, and change summary
# Replaces: git-context.sh, git-ancestor.sh, git-summary.sh

# Detect convention (name, default branch, protected branches)
DETECT_SCRIPT="$HOME/.claude/skills/detect-convention/scripts/detect-convention.sh"
CONVENTION=""
if [ -f "$DETECT_SCRIPT" ]; then
  CONVENTION_OUTPUT=$("$DETECT_SCRIPT" 2>/dev/null || echo "")
  CONVENTION=$(echo "$CONVENTION_OUTPUT" | sed -n '1p')
fi

if [ -n "$CONVENTION" ]; then
  echo "Convention: $CONVENTION"
fi

# Detect default branch
DEFAULT=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
DEFAULT=${DEFAULT:-main}

BRANCH=$(git branch --show-current)

echo "--- BRANCH ---"
echo "$BRANCH"

echo ""
echo "--- DEFAULT_BRANCH ---"
echo "$DEFAULT"

echo ""
echo "--- MERGED_PR ---"
if [ "$BRANCH" != "$DEFAULT" ]; then
  gh pr list --head "$BRANCH" --state merged --json number,title 2>/dev/null || echo "[]"
else
  echo "[]"
fi

echo ""
echo "--- EXISTING_PR ---"
if [ "$BRANCH" != "$DEFAULT" ]; then
  gh pr list --head "$BRANCH" --state open --json number,title,url 2>/dev/null || echo "[]"
else
  echo "[]"
fi

echo ""
echo "--- ANCESTOR ---"
MERGE_BASE=$(git merge-base HEAD "origin/$DEFAULT" 2>/dev/null || true)
if [ -n "$MERGE_BASE" ]; then
  EPIC=$(git branch -r --contains "$MERGE_BASE" 2>/dev/null | grep "epic/" | head -1 | tr -d ' ')
  if [ -n "$EPIC" ]; then
    echo "$EPIC"
    ANCESTOR="$EPIC"
  else
    echo "origin/$DEFAULT"
    ANCESTOR="origin/$DEFAULT"
  fi
else
  echo "origin/$DEFAULT"
  ANCESTOR="origin/$DEFAULT"
fi

echo ""
echo "--- COMMITS ---"
git log --oneline "$ANCESTOR..HEAD" 2>/dev/null || true

echo ""
echo "--- MILESTONES ---"
gh api repos/{owner}/{repo}/milestones --method GET -f state=all --jq '.[] | {number, title, state, open_issues, closed_issues}' 2>/dev/null || true

echo ""
echo "--- DIFFSTAT ---"
git diff "$ANCESTOR...HEAD" --stat 2>/dev/null || true
