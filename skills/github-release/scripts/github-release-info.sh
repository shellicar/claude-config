#!/bin/sh
# Gather all state needed before creating a GitHub release
# Outputs structured sections that Claude can parse in one read
#
# Usage: github-release-info.sh
#
# Sections output:
#   REPO            - repository name from git remote
#   BRANCH          - current branch name
#   WORKING_TREE    - clean or dirty
#   VERSION         - version from package.json (monorepo-aware)
#   CHANGELOG       - whether CHANGELOG.md contains the version entry
#   MILESTONE       - milestone data for this version (or not found)
#   EXISTING        - whether a release already exists for this version

set -e

# Detect convention
DETECT_SCRIPT="$HOME/.claude/skills/detect-convention/scripts/detect-convention.sh"
CONVENTION=""
if [ -f "$DETECT_SCRIPT" ]; then
  CONVENTION_OUTPUT=$("$DETECT_SCRIPT" 2>/dev/null || echo "")
  CONVENTION=$(echo "$CONVENTION_OUTPUT" | sed -n '1p')
fi

if [ -n "$CONVENTION" ]; then
  echo "Convention: $CONVENTION"
fi

section() {
  printf '\n--- %s ---\n' "$1"
}

# Repo name from git remote
section "REPO"
REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
if [ -n "$REMOTE" ]; then
  REPO=$(echo "$REMOTE" | sed 's/.*github.com[:/]//' | sed 's/\.git$//' | cut -d'/' -f2)
  OWNER=$(echo "$REMOTE" | sed 's/.*github.com[:/]//' | sed 's/\.git$//' | cut -d'/' -f1)
  echo "owner: $OWNER"
  echo "repo: $REPO"
else
  echo "ERROR: no git remote found"
  exit 1
fi

# Branch
section "BRANCH"
git branch --show-current

# Working tree
section "WORKING_TREE"
if git diff --quiet HEAD 2>/dev/null; then
  echo "clean"
else
  echo "dirty"
  git status --short
fi

# Version from package.json (try monorepo first, then root)
section "VERSION"
VERSION=""
if ls packages/*/package.json >/dev/null 2>&1; then
  VERSION=$(jq -r '.version' packages/*/package.json 2>/dev/null | head -1)
  echo "$VERSION (from packages/*/package.json)"
fi
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
  VERSION=$(jq -r '.version' package.json 2>/dev/null)
  echo "$VERSION (from package.json)"
fi
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
  echo "ERROR: no version found"
fi

# CHANGELOG check
section "CHANGELOG"
if [ -f CHANGELOG.md ]; then
  if grep -q "## \[$VERSION\]" CHANGELOG.md 2>/dev/null; then
    echo "found"
    grep "## \[$VERSION\]" CHANGELOG.md
  else
    echo "MISSING: no entry for $VERSION in CHANGELOG.md"
  fi
else
  echo "MISSING: no CHANGELOG.md file"
fi

# Open milestones
section "MILESTONE"
gh api "repos/$OWNER/$REPO/milestones" --jq '.[] | {title: .title, number: .number, open_issues: .open_issues, closed_issues: .closed_issues}' 2>/dev/null || echo "none"

# Existing release
section "EXISTING"
if [ -n "$VERSION" ] && [ "$VERSION" != "null" ]; then
  if gh release view "$VERSION" >/dev/null 2>&1; then
    echo "EXISTS: release $VERSION already exists"
    gh release view "$VERSION" --json tagName,publishedAt,url --jq '{tag: .tagName, published: .publishedAt, url: .url}'
  else
    echo "none"
  fi
else
  echo "SKIP: no version"
fi
