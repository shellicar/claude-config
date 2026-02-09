#!/bin/sh
# Azure DevOps REST API wrapper
# Constructs authenticated az rest calls with proper URL encoding
# Usage: ado-rest.sh --method METHOD --path PATH [--param KEY=VALUE]... [--temp-file] [-- extra az rest args...]

set -e

RESOURCE="499b84ac-1321-427f-aa17-267ca6975798"
METHOD=""
METHOD_SET=0
PATH_SEGMENT=""
PARAMS=""
TEMP_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --method)
      if [ "$METHOD_SET" -eq 1 ]; then
        echo "Error: --method specified more than once" >&2; exit 1
      fi
      METHOD="$2"; METHOD_SET=1; shift 2 ;;
    --path)    PATH_SEGMENT="$2"; shift 2 ;;
    --param)
      if [ -z "$PARAMS" ]; then
        PARAMS="$2"
      else
        PARAMS="${PARAMS}&${2}"
      fi
      shift 2
      ;;
    --temp-file) TEMP_FILE="$(mktemp)"; shift 1 ;;
    --)        shift; break ;;
    *)         echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Validate
if [ -z "$METHOD" ]; then
  echo "Error: --method is required" >&2
  echo "Usage: ado-rest.sh --method GET --path https://dev.azure.com/org/project/_apis/... [--param key=value]..." >&2
  exit 1
fi

if [ -z "$PATH_SEGMENT" ]; then
  echo "Error: --path is required" >&2
  echo "Usage: ado-rest.sh --method GET --path https://dev.azure.com/org/project/_apis/... [--param key=value]..." >&2
  exit 1
fi

# Sanitise: reject shell metacharacters in path and params
for val in "$PATH_SEGMENT" "$PARAMS"; do
  case "$val" in
    *\;*|*\`*|*\$\(*|*\|*) echo "Error: invalid characters in argument" >&2; exit 1 ;;
  esac
done

# Build URI
if [ -n "$PARAMS" ]; then
  URI="${PATH_SEGMENT}?${PARAMS}"
else
  URI="$PATH_SEGMENT"
fi

# Execute - "$@" preserves quoting of remaining args
if [ -n "$TEMP_FILE" ]; then
  az rest --method "$METHOD" --uri "$URI" --resource "$RESOURCE" "$@" > "$TEMP_FILE"
  echo "$TEMP_FILE"
else
  az rest --method "$METHOD" --uri "$URI" --resource "$RESOURCE" "$@"
fi
