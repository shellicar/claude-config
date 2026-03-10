#!/bin/sh
# Detect which convention applies to the current repository
# Requires BOTH remote URL AND directory path to match (strict mode)
#
# Output: JSON
#   {"convention":"...","default_branch":"..."}

set -e

# Detect default branch from origin/HEAD
detect_default_branch() {
  branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
  if [ -z "$branch" ]; then
    git remote set-head origin --auto >/dev/null 2>&1 || true
    branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
  fi
  echo "$branch"
}

# Detect convention from remote URL and directory path
detect_convention() {
  remote=$(git remote get-url origin 2>/dev/null || echo "")
  dir=$(pwd -P)

  if [ -z "$remote" ]; then
    echo "ERROR: No git remote found" >&2
    return 1
  fi

  # GitHub conventions - require remote AND directory match
  if echo "$remote" | grep -q "github.com/shellicar/"; then
    if [ "$dir" = "$HOME/.claude" ] || [ "$dir" = "$HOME/dotfiles" ]; then
      echo "shellicar-config"
      return 0
    elif echo "$dir" | grep -q "^$HOME/repos/@shellicar/"; then
      echo "shellicar-oss"
      return 0
    elif echo "$dir" | grep -q "^$HOME/repos/shellicar/"; then
      echo "shellicar"
      return 0
    fi
  fi

  # Azure DevOps conventions - require remote AND directory match
  if echo "$remote" | grep -q "dev.azure.com/eagersautomotive/"; then
    if echo "$dir" | grep -q "^$HOME/repos/Eagers/"; then
      echo "eagers"
      return 0
    fi
  fi

  if echo "$remote" | grep -qi "dev.azure.com/hopeventures/"; then
    if echo "$dir" | grep -q "^$HOME/repos/HopeVentures/"; then
      echo "hopeventures"
      return 0
    fi
  fi

  if echo "$remote" | grep -q "dev.azure.com/Flightrac/"; then
    if echo "$dir" | grep -q "^$HOME/repos/Flightrac/"; then
      echo "flightrac"
      return 0
    fi
  fi

  echo "ERROR: No convention matches" >&2
  echo "  Remote: $remote" >&2
  echo "  Directory: $dir" >&2
  return 1
}

CONVENTION=$(detect_convention)
DEFAULT_BRANCH=$(detect_default_branch)

printf '{"convention":"%s","default_branch":"%s"}\n' \
  "$CONVENTION" "$DEFAULT_BRANCH"
