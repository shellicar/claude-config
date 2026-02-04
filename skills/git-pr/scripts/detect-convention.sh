#!/bin/sh
# Detect which convention applies to the current repository
# Outputs the convention name on success, exits with error if no match
# Requires BOTH remote URL AND directory path to match (strict mode)

set -e

REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
PWD_REAL=$(pwd -P)

# Fail if no remote
if [ -z "$REMOTE" ]; then
  echo "ERROR: No git remote found" >&2
  exit 1
fi

# GitHub conventions - require remote AND directory match
if echo "$REMOTE" | grep -q "github.com/shellicar/"; then
  if echo "$PWD_REAL" | grep -q "^$HOME/repos/@shellicar/"; then
    echo "shellicar-oss"
    exit 0
  elif echo "$PWD_REAL" | grep -q "^$HOME/repos/shellicar/"; then
    echo "shellicar"
    exit 0
  fi
fi

# Azure DevOps conventions - require remote AND directory match
if echo "$REMOTE" | grep -q "dev.azure.com/eagersautomotive/"; then
  if echo "$PWD_REAL" | grep -q "^$HOME/repos/Eagers/"; then
    echo "eagers"
    exit 0
  fi
fi

if echo "$REMOTE" | grep -qi "dev.azure.com/hopeventures/"; then
  if echo "$PWD_REAL" | grep -q "^$HOME/repos/HopeVentures/"; then
    echo "hopeventures"
    exit 0
  fi
fi

if echo "$REMOTE" | grep -q "dev.azure.com/Flightrac/"; then
  if echo "$PWD_REAL" | grep -q "^$HOME/repos/Flightrac/"; then
    echo "flightrac"
    exit 0
  fi
fi

# No match - fail explicitly
echo "ERROR: No convention matches" >&2
echo "  Remote: $REMOTE" >&2
echo "  Directory: $PWD_REAL" >&2
exit 1
