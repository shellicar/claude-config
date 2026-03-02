#!/bin/sh
# Generate an Azure DevOps Personal Access Token using the Azure CLI session.
# Uses az rest to create a PAT via the VSSPS API.
# See: https://github.com/jongio/azure-cli-awesome/blob/main/create-devops-pat.azcli
# Scopes: https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/oauth?view=azure-devops#available-scopes
#
# Usage:
#   ado-generate-pat.sh --org <ORG> [--name <PAT_NAME>] [--scopes <SCOPES>]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ORG=""
PAT_NAME="AZCLIGeneratedPat"
SCOPES="vso.packaging_manage"

while [ $# -gt 0 ]; do
  case $1 in
    --org)
      ORG="$2"
      shift 2
      ;;
    --name)
      PAT_NAME="$2"
      shift 2
      ;;
    --scopes)
      SCOPES="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ado-generate-pat.sh --org <ORG> [--name <PAT_NAME>] [--scopes <SCOPES>]"
      echo ""
      echo "  --org     Azure DevOps organisation name (required)"
      echo "  --name    Display name for the PAT (default: AZCLIGeneratedPat)"
      echo "  --scopes  Space-delimited scopes (default: vso.packaging_manage)"
      exit 0
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

# Write the request body to a temp file (cli-tools convention: no inline JSON)
BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT

printf '{"displayName":"%s","scope":"%s"}' "$PAT_NAME" "$SCOPES" > "$BODY_FILE"

echo "✅ Creating PAT '$PAT_NAME' in organisation '$ORG'" >&2

TOKEN=$("$SCRIPT_DIR/ado-rest.sh" \
  --method POST \
  --path "https://vssps.dev.azure.com/$ORG/_apis/Tokens/Pats" \
  --param 'api-version=6.1-preview' \
  -- --headers 'Content-Type=application/json' --body "@$BODY_FILE" --query "patToken.token" --output tsv)

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to create PAT in organisation '$ORG'" >&2
  exit 1
fi

echo "✅ Created PAT '$PAT_NAME' with scopes '$SCOPES'" >&2
echo "" >&2
echo "Run the following to configure Azure DevOps CLI:" >&2
echo "  export AZURE_DEVOPS_EXT_PAT=$TOKEN" >&2
echo "  az config set extension.use_dynamic_install=yes_without_prompt" >&2
echo "  echo \$AZURE_DEVOPS_EXT_PAT | az devops login --organization https://dev.azure.com/$ORG/" >&2

# Output only the token on stdout for piping
echo "$TOKEN"
