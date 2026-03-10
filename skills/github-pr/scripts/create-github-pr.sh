#!/bin/sh
set -e

# create-github-pr.sh - Create a GitHub PR, reads JSON from stdin
#
# Usage: jq -n '{...}' | create-github-pr.sh
#
# Input JSON fields:
#   title     (required) - PR title
#   body      (required) - PR body (multiline supported)
#   milestone (required) - Milestone title
#   assignee  (required) - Assignee (@me or username)
#   labels    (optional) - Array of label names
#
# Example:
#   jq -n '{
#     title: "Fix login bug",
#     body: "## Summary\n\n- Fix null pointer on login",
#     milestone: "1.3",
#     assignee: "@me",
#     labels: ["bug"]
#   }' | create-github-pr.sh
#
# This script enforces that all required fields are provided.
# It wraps gh pr create to prevent ad-hoc calls that skip required fields.

INPUT=$(cat)

# Extract required fields
TITLE=$(printf '%s' "$INPUT" | jq -r '.title // empty')
BODY=$(printf '%s' "$INPUT" | jq -r '.body // empty')
MILESTONE=$(printf '%s' "$INPUT" | jq -r '.milestone // empty')
ASSIGNEE=$(printf '%s' "$INPUT" | jq -r '.assignee // empty')

# Validate required fields
MISSING=""
[ -z "$TITLE" ]     && MISSING="$MISSING title"
[ -z "$BODY" ]      && MISSING="$MISSING body"
[ -z "$MILESTONE" ] && MISSING="$MISSING milestone"
[ -z "$ASSIGNEE" ]  && MISSING="$MISSING assignee"

if [ -n "$MISSING" ]; then
  printf 'Error: Missing required fields:%s\n' "$MISSING" >&2
  printf 'All of title, body, milestone, assignee are required.\n' >&2
  printf 'Use the github-milestone skill to resolve the milestone before calling this script.\n' >&2
  exit 1
fi

# Build label args from array
LABEL_ARGS=""
while IFS= read -r label; do
  [ -n "$label" ] && LABEL_ARGS="$LABEL_ARGS --label $label"
done <<LABELS
$(printf '%s' "$INPUT" | jq -r '.labels[]? // empty')
LABELS

# Execute gh pr create
# LABEL_ARGS intentionally unquoted to split into separate --label flags
# shellcheck disable=SC2086
gh pr create \
  --title "$TITLE" \
  --body "$BODY" \
  --milestone "$MILESTONE" \
  --assignee "$ASSIGNEE" \
  $LABEL_ARGS
