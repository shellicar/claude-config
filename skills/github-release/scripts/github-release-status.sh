#!/bin/sh
# Check post-release status: workflow, npm availability, milestone
# Outputs JSON that Claude can parse in one read
#
# Usage: github-release-status.sh <version>
#
# Output fields:
#   version     - the version being checked
#   workflow    - latest npm-publish workflow run object, or null
#   npm         - {package, latest, published}
#   milestones  - array of milestone objects

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

# Workflow status (latest npm-publish run)
WORKFLOW=$(gh run list --workflow=npm-publish.yml --limit=1 \
  --json status,conclusion,databaseId,displayTitle 2>/dev/null | jq '.[0] // null')

# npm availability
NPM_LATEST=""
NPM_PUBLISHED="false"
if [ -n "$PKG_NAME" ] && [ "$PKG_NAME" != "null" ]; then
  NPM_LATEST=$(npm view "$PKG_NAME" version 2>/dev/null || echo "")
  if [ "$NPM_LATEST" = "$VERSION" ]; then
    NPM_PUBLISHED="true"
  fi
fi

# Open milestones
MILESTONES=$(gh api "repos/$OWNER/$REPO/milestones" \
  --jq '[.[] | {title: .title, number: .number, state: .state, open_issues: .open_issues, closed_issues: .closed_issues}]' \
  2>/dev/null || echo "[]")

jq -n \
  --arg version "$VERSION" \
  --argjson workflow "$WORKFLOW" \
  --arg pkg_name "${PKG_NAME:-}" \
  --arg npm_latest "${NPM_LATEST:-}" \
  --argjson npm_published "$NPM_PUBLISHED" \
  --argjson milestones "$MILESTONES" \
  '{version: $version, workflow: $workflow, npm: {package: $pkg_name, latest: $npm_latest, published: $npm_published}, milestones: $milestones}'
