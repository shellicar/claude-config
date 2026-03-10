#!/bin/sh
# Gather all state needed before creating a GitHub release
# Outputs JSON that Claude can parse in one read
#
# Usage: github-release-info.sh
#
# Output fields:
#   convention      - detected convention name
#   owner           - GitHub owner from git remote
#   repo            - GitHub repo name from git remote
#   branch          - current branch name
#   working_tree    - "clean" or "dirty"
#   version         - version from package.json (monorepo-aware)
#   changelog       - "found" or "missing"
#   milestones      - array of open milestone objects
#   existing_release - release object if exists, else null

set -e

# Detect convention
DETECT_SCRIPT="$HOME/.claude/skills/detect-convention/scripts/detect-convention.sh"
CONVENTION=""
if [ -f "$DETECT_SCRIPT" ]; then
  CONVENTION=$(("$DETECT_SCRIPT" 2>/dev/null || echo '{}') | jq -r '.convention // ""')
fi

# Repo owner/name from git remote
REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
if [ -z "$REMOTE" ]; then
  echo "ERROR: no git remote found" >&2
  exit 1
fi
REPO=$(echo "$REMOTE" | sed 's/.*github.com[:/]//' | sed 's/\.git$//' | cut -d'/' -f2)
OWNER=$(echo "$REMOTE" | sed 's/.*github.com[:/]//' | sed 's/\.git$//' | cut -d'/' -f1)

# Branch
BRANCH=$(git branch --show-current)

# Working tree
if git diff --quiet HEAD 2>/dev/null; then
  WORKING_TREE="clean"
else
  WORKING_TREE="dirty"
fi

# Version from package.json (try monorepo first, then root)
VERSION=""
if ls packages/*/package.json >/dev/null 2>&1; then
  VERSION=$(jq -r '.version' packages/*/package.json 2>/dev/null | head -1)
fi
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
  VERSION=$(jq -r '.version' package.json 2>/dev/null)
fi

# CHANGELOG check
CHANGELOG_STATUS="missing"
if [ -f CHANGELOG.md ]; then
  if grep -q "## \[$VERSION\]" CHANGELOG.md 2>/dev/null; then
    CHANGELOG_STATUS="found"
  fi
fi

# Open milestones
MILESTONES=$(gh api "repos/$OWNER/$REPO/milestones" \
  --jq '[.[] | {title: .title, number: .number, open_issues: .open_issues, closed_issues: .closed_issues}]' \
  2>/dev/null || echo "[]")

# Existing release
EXISTING_RELEASE="null"
if [ -n "$VERSION" ] && [ "$VERSION" != "null" ]; then
  if gh release view "$VERSION" >/dev/null 2>&1; then
    EXISTING_RELEASE=$(gh release view "$VERSION" \
      --json tagName,publishedAt,url \
      --jq '{tag: .tagName, published: .publishedAt, url: .url}')
  fi
fi

jq -n \
  --arg convention "$CONVENTION" \
  --arg owner "$OWNER" \
  --arg repo "$REPO" \
  --arg branch "$BRANCH" \
  --arg working_tree "$WORKING_TREE" \
  --arg version "${VERSION:-}" \
  --arg changelog "$CHANGELOG_STATUS" \
  --argjson milestones "$MILESTONES" \
  --argjson existing_release "$EXISTING_RELEASE" \
  '{convention: $convention, owner: $owner, repo: $repo, branch: $branch, working_tree: $working_tree, version: $version, changelog: $changelog, milestones: $milestones, existing_release: $existing_release}'
