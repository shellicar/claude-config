#!/bin/sh
# Step 3: Commit summary - diff from ancestor to HEAD

# Find ancestor (simplified - picks first epic branch or defaults to main)
DEFAULT=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
DEFAULT=${DEFAULT:-main}
MERGE_BASE=$(git merge-base HEAD origin/$DEFAULT 2>/dev/null)
ANCESTOR=$(git branch -r --contains $MERGE_BASE 2>/dev/null | grep "epic/" | head -1 | tr -d ' ')
ANCESTOR=${ANCESTOR:-origin/$DEFAULT}

echo "Ancestor: $ANCESTOR"
echo ""
echo "=== Staged Changes ==="
git diff --staged --stat
echo ""
echo "=== Commits since $ANCESTOR ==="
git log --oneline $ANCESTOR..HEAD
echo ""
echo "=== Diff from $ANCESTOR ==="
git diff $ANCESTOR...HEAD --stat
