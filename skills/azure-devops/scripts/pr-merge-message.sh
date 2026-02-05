#!/bin/sh
# Generate or validate Azure DevOps PR merge commit message
#
# Usage:
#   pr-merge-message.sh --org <ORG_NAME> --id <PR_ID> [--validate|--set|--show|--set-auto-complete]
#
# Options:
#   --org              Azure DevOps organization name (required, e.g., "hopeventures")
#   --id               PR ID (required)
#   --validate         Compare current merge commit message against expected (default)
#   --set              Update the merge commit message to match expected format
#   --show             Just show what the merge commit message should be
#   --set-auto-complete  Set auto-complete with squash, transition-work-items, AND merge commit message
#
# Expected format:
#   Merged PR {id}: {title}
#
#   {description}

set +e

# --- Functions ---

check_not_completed() {
  if [ "$STATUS" = "completed" ]; then
    echo "PR $PR_ID is already merged - $1"
    exit 1
  fi
}

check_has_title() {
  if [ -z "$TITLE" ]; then
    echo "Error: PR has no title - cannot generate merge commit message"
    exit 1
  fi
}

build_expected_msg() {
  printf "Merged PR %s: %s\n\n%s" "$PR_ID" "$TITLE" "$DESCRIPTION"
}

compare_messages() {
  local expected="$1"
  local actual="$2"
  local expected_file actual_file

  expected_file=$(mktemp)
  actual_file=$(mktemp)
  printf '%s' "$expected" > "$expected_file"
  printf '%s' "$actual" > "$actual_file"

  if diff -q "$expected_file" "$actual_file" > /dev/null 2>&1; then
    rm -f "$expected_file" "$actual_file"
    return 0
  else
    echo ""
    echo "=== DIFF (expected vs actual) ==="
    diff "$expected_file" "$actual_file" || true
    rm -f "$expected_file" "$actual_file"
    return 1
  fi
}

fetch_pr_field() {
  az repos pr show --id "$PR_ID" --org "$ORG_URL" --query "$1" -o tsv 2>/dev/null
}

do_show() {
  echo "$EXPECTED_MSG"
}

do_validate() {
  check_not_completed "cannot validate merge commit message via API"

  if [ -z "$CURRENT_MSG" ] || [ "$CURRENT_MSG" = "None" ]; then
    echo "No merge commit message set (auto-complete not enabled?)"
    exit 1
  fi

  if compare_messages "$EXPECTED_MSG" "$CURRENT_MSG"; then
    echo "✓ Merge commit message matches expected format"
    exit 0
  else
    echo "✗ Merge commit message differs from expected"
    exit 1
  fi
}

do_set() {
  check_not_completed "cannot update merge commit message"

  az repos pr update --id "$PR_ID" --org "$ORG_URL" \
    --merge-commit-message "$EXPECTED_MSG" > /dev/null
  echo "✓ Merge commit message updated"
}

do_set_auto_complete() {
  check_not_completed "cannot set auto-complete"
  check_has_title

  az repos pr update --id "$PR_ID" --org "$ORG_URL" \
    --auto-complete true --squash true --transition-work-items true \
    --merge-commit-message "$EXPECTED_MSG" > /dev/null
  echo "✅ Auto-complete set with merge commit message"

  # Validate it was set correctly
  UPDATED_MSG=$(fetch_pr_field "completionOptions.mergeCommitMessage")

  if compare_messages "$EXPECTED_MSG" "$UPDATED_MSG"; then
    echo "✓ Merge commit message validated"
    exit 0
  else
    echo "❌ Merge commit message validation failed"
    exit 1
  fi
}

# --- Main ---

# Parse arguments
PR_ID=""
ORG=""
MODE="validate"

while [ $# -gt 0 ]; do
  case $1 in
    --id)
      PR_ID="$2"
      shift 2
      ;;
    --org)
      ORG="$2"
      shift 2
      ;;
    --validate)
      MODE="validate"
      shift
      ;;
    --set)
      MODE="set"
      shift
      ;;
    --show)
      MODE="show"
      shift
      ;;
    --set-auto-complete)
      MODE="set-auto-complete"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$ORG" ]; then
  echo "Error: --org is required" >&2
  exit 1
fi

if [ -z "$PR_ID" ]; then
  echo "Error: --id is required" >&2
  exit 1
fi

# Build org URL from org name
ORG_URL="https://dev.azure.com/${ORG}"

# Query PR fields
STATUS=$(fetch_pr_field "status")
TITLE=$(fetch_pr_field "title")
DESCRIPTION=$(fetch_pr_field "description")
CURRENT_MSG=$(fetch_pr_field "completionOptions.mergeCommitMessage")

# Build expected merge commit message
EXPECTED_MSG=$(build_expected_msg)

# Execute mode
case $MODE in
  show)
    do_show
    ;;
  validate)
    do_validate
    ;;
  set)
    do_set
    ;;
  set-auto-complete)
    do_set_auto_complete
    ;;
esac
