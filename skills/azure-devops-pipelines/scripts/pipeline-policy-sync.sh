#!/bin/sh
# Compare or sync YAML pipeline triggers with build validation policies
#
# Usage:
#   pipeline-policy-sync.sh --org <ORG> --project <PROJECT> --yaml <PATH> --pipeline-id <ID> [--compare|--sync]
#
# Options:
#   --org          Azure DevOps organization name (required)
#   --project      Azure DevOps project name (required)
#   --yaml         Path to azure-pipelines.yml file (required)
#   --pipeline-id  Pipeline/build definition ID (required)
#   --compare      Show differences between YAML and policy (default)
#   --sync         Update policy to match YAML

set +e

ORG=""
PROJECT=""
YAML_PATH=""
PIPELINE_ID=""
MODE="compare"

while [ $# -gt 0 ]; do
  case "$1" in
    --org)
      ORG="$2"
      shift 2
      ;;
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --yaml)
      YAML_PATH="$2"
      shift 2
      ;;
    --pipeline-id)
      PIPELINE_ID="$2"
      shift 2
      ;;
    --compare)
      MODE="compare"
      shift
      ;;
    --sync)
      MODE="sync"
      shift
      ;;
    -h|--help)
      echo "Usage: pipeline-policy-sync.sh --org <ORG> --project <PROJECT> --yaml <PATH> --pipeline-id <ID> [--compare|--sync]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "$ORG" ]; then
  echo "❌ Error: --org is required" >&2
  exit 1
fi

if [ -z "$PROJECT" ]; then
  echo "❌ Error: --project is required" >&2
  exit 1
fi

if [ -z "$YAML_PATH" ]; then
  echo "❌ Error: --yaml is required" >&2
  exit 1
fi

if [ -z "$PIPELINE_ID" ]; then
  echo "❌ Error: --pipeline-id is required" >&2
  exit 1
fi

if [ ! -f "$YAML_PATH" ]; then
  echo "❌ Error: YAML file not found: $YAML_PATH" >&2
  exit 1
fi

ORG_URL="https://dev.azure.com/$ORG"

# Temp files for comparison
tmp_policy=$(mktemp)
tmp_yaml=$(mktemp)
trap 'rm -f "$tmp_policy" "$tmp_yaml"' EXIT

# Extract trigger paths from YAML
extract_yaml_triggers() {
  yaml_file="$1"
  in_trigger=0
  in_paths=0
  in_include=0
  in_exclude=0

  while IFS= read -r line; do
    # Remove leading whitespace for pattern matching
    trimmed=$(printf '%s' "$line" | tr -d ' ')

    case "$trimmed" in
      "trigger:")
        in_trigger=1
        ;;
      "paths:")
        if [ $in_trigger -eq 1 ]; then
          in_paths=1
        fi
        ;;
      "include:")
        if [ $in_paths -eq 1 ]; then
          in_include=1
          in_exclude=0
        fi
        ;;
      "exclude:")
        if [ $in_paths -eq 1 ]; then
          in_exclude=1
          in_include=0
        fi
        ;;
      "stages:"*|"jobs:"*|"steps:"*)
        # End of trigger section
        in_trigger=0
        in_paths=0
        in_include=0
        in_exclude=0
        ;;
      -*)
        if [ $in_include -eq 1 ]; then
          # Extract path after "- "
          path=$(printf '%s' "$line" | grep -o '\- .*' | cut -c3-)
          printf 'include:%s\n' "$path"
        elif [ $in_exclude -eq 1 ]; then
          path=$(printf '%s' "$line" | grep -o '\- .*' | cut -c3-)
          printf 'exclude:%s\n' "$path"
        fi
        ;;
    esac
  done < "$yaml_file"
}

# Convert YAML paths to policy format
# YAML: apps/api, packages/*
# Policy: /apps/api/*, /packages/*
# Note: Files (with extension) don't get /* suffix
yaml_to_policy_format() {
  yaml_path="$1"
  type="$2"

  # Add leading / if not present
  case "$yaml_path" in
    /*)
      # Already has leading /
      ;;
    *)
      yaml_path="/$yaml_path"
      ;;
  esac

  # Add trailing /* only for directories (not files with extensions)
  # and only if not already a wildcard
  case "$yaml_path" in
    *\*)
      # Already has wildcard
      ;;
    *.yml|*.yaml|*.ts|*.js|*.json|*.md|*.txt)
      # File with extension - no wildcard needed
      ;;
    *)
      # Directory - add wildcard
      yaml_path="$yaml_path/*"
      ;;
  esac

  if [ "$type" = "exclude" ]; then
    printf '!%s\n' "$yaml_path"
  else
    printf '%s\n' "$yaml_path"
  fi
}

# Get policy ID
get_policy_id() {
  az repos policy list --project "$PROJECT" --org "$ORG_URL" \
    --query "[?type.displayName=='Build' && settings.buildDefinitionId==\`$PIPELINE_ID\`] | [0].id" -o tsv 2>/dev/null
}

# Get policy patterns (one per line)
get_policy_patterns() {
  az repos policy list --project "$PROJECT" --org "$ORG_URL" \
    --query "[?type.displayName=='Build' && settings.buildDefinitionId==\`$PIPELINE_ID\`] | [0].settings.filenamePatterns[]" -o tsv 2>/dev/null
}

# Get repository ID from policy
get_repo_id() {
  az repos policy list --project "$PROJECT" --org "$ORG_URL" \
    --query "[?type.displayName=='Build' && settings.buildDefinitionId==\`$PIPELINE_ID\`] | [0].settings.scope[0].repositoryId" -o tsv 2>/dev/null
}

# Main logic
echo "Pipeline Policy Sync"
echo "===================="
echo "Organization: $ORG"
echo "Project: $PROJECT"
echo "YAML file: $YAML_PATH"
echo "Pipeline ID: $PIPELINE_ID"
echo "Mode: $MODE"
echo ""

# Get current policy
policy_id=$(get_policy_id)

if [ -z "$policy_id" ]; then
  echo "❌ No build validation policy found for pipeline ID $PIPELINE_ID" >&2
  exit 1
fi

echo "Policy ID: $policy_id"
echo ""

# Get current policy patterns
get_policy_patterns | sort > "$tmp_policy"

# Extract YAML triggers and convert to policy format
yaml_triggers=$(extract_yaml_triggers "$YAML_PATH")

for trigger in $yaml_triggers; do
  type=$(printf '%s' "$trigger" | cut -d: -f1)
  path=$(printf '%s' "$trigger" | cut -d: -f2-)
  yaml_to_policy_format "$path" "$type"
done | sort > "$tmp_yaml"

echo "=== Current Policy Patterns ==="
cat "$tmp_policy"
echo ""

echo "=== Expected Patterns (from YAML) ==="
cat "$tmp_yaml"
echo ""

# Compare using temp files
echo "=== Differences ==="

# Find patterns in policy but not in YAML
in_policy_only=""
while IFS= read -r pattern; do
  if [ -n "$pattern" ] && ! grep -qxF "$pattern" "$tmp_yaml"; then
    in_policy_only="$in_policy_only$pattern
"
  fi
done < "$tmp_policy"

# Find patterns in YAML but not in policy
in_yaml_only=""
while IFS= read -r pattern; do
  if [ -n "$pattern" ] && ! grep -qxF "$pattern" "$tmp_policy"; then
    in_yaml_only="$in_yaml_only$pattern
"
  fi
done < "$tmp_yaml"

has_diff=0

if [ -n "$in_policy_only" ]; then
  echo "In policy but not in YAML (will be removed):"
  printf '%s' "$in_policy_only" | while IFS= read -r p; do
    [ -n "$p" ] && echo "  - $p"
  done
  has_diff=1
fi

if [ -n "$in_yaml_only" ]; then
  echo "In YAML but not in policy (will be added):"
  printf '%s' "$in_yaml_only" | while IFS= read -r p; do
    [ -n "$p" ] && echo "  + $p"
  done
  has_diff=1
fi

if [ $has_diff -eq 0 ]; then
  echo "✅ Policy matches YAML - no differences found"
  exit 0
fi

if [ "$MODE" = "compare" ]; then
  echo ""
  echo "Run with --sync to update the policy"
  exit 0
fi

# Sync mode - update the policy
echo ""
echo "Updating policy..."

# Build the new filenamePatterns JSON array from YAML patterns
new_patterns_json="["
first=1
while IFS= read -r pattern; do
  if [ -n "$pattern" ]; then
    if [ $first -eq 1 ]; then
      first=0
    else
      new_patterns_json="$new_patterns_json,"
    fi
    new_patterns_json="$new_patterns_json\"$pattern\""
  fi
done < "$tmp_yaml"
new_patterns_json="$new_patterns_json]"

# Get repository ID from policy
repo_id=$(get_repo_id)

# Update the policy
update_result=$(az rest --method PUT \
  --uri "$ORG_URL/$PROJECT/_apis/policy/configurations/$policy_id?api-version=7.1" \
  --resource "499b84ac-1321-427f-aa17-267ca6975798" \
  --headers "Content-Type=application/json" \
  --body "{
    \"isEnabled\": true,
    \"isBlocking\": true,
    \"type\": {
      \"id\": \"0609b952-1397-4640-95ec-e00a01b2c241\"
    },
    \"settings\": {
      \"buildDefinitionId\": $PIPELINE_ID,
      \"queueOnSourceUpdateOnly\": false,
      \"manualQueueOnly\": false,
      \"displayName\": null,
      \"validDuration\": 0.0,
      \"scope\": [
        {
          \"repositoryId\": \"$repo_id\",
          \"refName\": \"refs/heads/main\",
          \"matchKind\": \"Exact\"
        }
      ],
      \"filenamePatterns\": $new_patterns_json
    }
  }" 2>&1)

if printf '%s' "$update_result" | grep -q '"revision"'; then
  new_revision=$(printf '%s' "$update_result" | grep -o '"revision": [0-9]*' | grep -o '[0-9]*')
  echo "✅ Policy updated successfully (revision $new_revision)"
else
  echo "❌ Failed to update policy:" >&2
  printf '%s\n' "$update_result" >&2
  exit 1
fi
