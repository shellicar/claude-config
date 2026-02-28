#!/bin/sh
# Check post-release status: workflow, npm availability, milestone
# Outputs structured sections that Claude can parse in one read
#
# Usage: github-release-status.sh <version>
#
# Sections output:
#   WORKFLOW    - latest npm-publish workflow run status
#   NPM         - whether the version is available on npm
#   MILESTONE   - milestone number and state (for closing)

set -e

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Usage: github-release-status.sh <version>" >&2
  exit 1
fi

REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
REPO=$(echo "$REMOTE" | sed 's/.*github.com[:/]//' | sed 's/\.git$//' | cut -d'/' -f2)
OWNER=$(echo "$REMOTE" | sed 's/.*github.com[:/]//' | sed 's/\.git$//' | cut -d'/' -f1)

# Get package name from package.json
PKG_NAME=""
if ls packages/*/package.json >/dev/null 2>&1; then
  PKG_NAME=$(jq -r '.name' packages/*/package.json 2>/dev/null | head -1)
fi
if [ -z "$PKG_NAME" ] || [ "$PKG_NAME" = "null" ]; then
  PKG_NAME=$(jq -r '.name' package.json 2>/dev/null)
fi

section() {
  printf '\n--- %s ---\n' "$1"
}

# Workflow status
section "WORKFLOW"
gh run list --workflow=npm-publish.yml --limit=1 --json status,conclusion,databaseId,displayTitle 2>/dev/null || echo "no npm-publish workflow found"

# npm availability
section "NPM"
if [ -n "$PKG_NAME" ] && [ "$PKG_NAME" != "null" ]; then
  echo "package: $PKG_NAME"
  NPM_VERSION=$(npm view "$PKG_NAME" version 2>/dev/null || echo "not found")
  echo "latest: $NPM_VERSION"
  if [ "$NPM_VERSION" = "$VERSION" ]; then
    echo "PUBLISHED: $VERSION is live on npm"
  else
    echo "PENDING: npm shows $NPM_VERSION, expected $VERSION"
  fi
else
  echo "SKIP: no package name found"
fi

# Milestone
section "MILESTONE"
MILESTONE_JSON=$(gh api "repos/$OWNER/$REPO/milestones" --jq ".[] | select(.title == \"$VERSION\")" 2>/dev/null || echo "")
if [ -n "$MILESTONE_JSON" ]; then
  echo "$MILESTONE_JSON" | jq '{number: .number, title: .title, state: .state, open_issues: .open_issues, closed_issues: .closed_issues}'
else
  echo "not found"
fi
