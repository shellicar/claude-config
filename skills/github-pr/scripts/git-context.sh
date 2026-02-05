#!/bin/sh
# Step 1: Detect git context
echo "Branch: $(git branch --show-current)"
echo "Remote: $(git remote get-url origin 2>/dev/null)"
echo "Email: $(git config --local user.email 2>/dev/null)"
