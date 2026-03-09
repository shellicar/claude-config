#!/bin/sh
# Gather all git state needed for a push decision
# Outputs structured sections that Claude can parse in one read
#
# Usage: git-push-info.sh
#
# Sections output:
#   BRANCH          - current branch name
#   HAS_UPSTREAM    - whether the branch has an upstream tracking branch
#   COMMITS_TO_PUSH - commits that would be pushed (oneline)
#   DIVERGENCE      - behind/ahead counts relative to upstream
#   DIFFSTAT        - file-level summary of changes per commit (for triage before scanning)

set -e

# Detect convention (name, default branch, protected branches)
DETECT_SCRIPT="$HOME/.claude/skills/detect-convention/scripts/detect-convention.sh"
CONVENTION=""
PROTECTED_BRANCHES="none"
if [ -f "$DETECT_SCRIPT" ]; then
  CONVENTION_OUTPUT=$("$DETECT_SCRIPT" 2>/dev/null || echo "")
  CONVENTION=$(echo "$CONVENTION_OUTPUT" | sed -n '1p')
  PROTECTED_BRANCHES=$(echo "$CONVENTION_OUTPUT" | sed -n '3p')
  [ -z "$PROTECTED_BRANCHES" ] && PROTECTED_BRANCHES="none"
fi

if [ -n "$CONVENTION" ]; then
  echo "Convention: $CONVENTION"
fi

section() {
  printf '\n--- %s ---\n' "$1"
}

# Branch
section "BRANCH"
BRANCH=$(git branch --show-current)
echo "$BRANCH"

# Protected branches
section "PROTECTED_BRANCHES"
echo "$PROTECTED_BRANCHES"

# Check for upstream
section "HAS_UPSTREAM"
if git rev-parse --abbrev-ref "@{u}" >/dev/null 2>&1; then
  UPSTREAM=$(git rev-parse --abbrev-ref "@{u}")
  echo "yes ($UPSTREAM)"
  HAS_UPSTREAM=true
else
  echo "no (new branch)"
  HAS_UPSTREAM=false
fi

# Commits to push
section "COMMITS_TO_PUSH"
if [ "$HAS_UPSTREAM" = true ]; then
  COMMITS=$(git log @{u}..HEAD --oneline)
  if [ -z "$COMMITS" ]; then
    echo "(no commits to push)"
  else
    echo "$COMMITS"
  fi
else
  git log --oneline -10
  echo "(new branch — showing last 10 commits)"
fi

# Divergence
section "DIVERGENCE"
if [ "$HAS_UPSTREAM" = true ]; then
  git rev-list --left-right --count @{u}...HEAD
else
  echo "SKIP: no upstream"
fi

# Diffstat per commit (lightweight — no content, just file names and sizes)
section "DIFFSTAT"
if [ "$HAS_UPSTREAM" = true ]; then
  HASHES=$(git log @{u}..HEAD --format="%H")
else
  HASHES=$(git log --format="%H" -10)
fi

if [ -z "$HASHES" ]; then
  echo "(no commits to scan)"
else
  echo "$HASHES" | while read -r hash; do
    printf '\n=== %s ===\n' "$(git log -1 --format='%h %s' "$hash")"
    git diff-tree --no-commit-id -r --stat "$hash"
  done
fi
