#!/bin/sh
# Step 2: Determine ancestor branch
DEFAULT=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
DEFAULT=${DEFAULT:-main}
echo "Default: $DEFAULT"
MERGE_BASE=$(git merge-base HEAD origin/$DEFAULT 2>/dev/null)
echo "MergeBase: $MERGE_BASE"
echo "Intermediates:"
git branch -r --contains $MERGE_BASE 2>/dev/null | grep -v "origin/$DEFAULT" | grep -v "origin/HEAD"
