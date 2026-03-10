#!/bin/sh
# Generate an Azure DevOps Personal Access Token using the Azure CLI session.
# Uses az rest to create a PAT via the VSSPS API.
# See: https://github.com/jongio/azure-cli-awesome/blob/main/create-devops-pat.azcli
# Scopes: https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/oauth?view=azure-devops#available-scopes
#
# Usage:
#   echo '{"org":"myorg"}' | ado-generate-pat.sh
#   echo '{"org":"myorg","name":"MyPat","scopes":"vso.code vso.build"}' | ado-generate-pat.sh
#
# Input JSON fields:
#   org     Azure DevOps organisation name (required)
#   name    Display name for the PAT (default: AZCLIGeneratedPat)
#   scopes  Space-delimited scopes (default: vso.packaging_manage)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

INPUT=$(cat)
ORG=$(printf '%s' "$INPUT" | jq -r '.org')
PAT_NAME=$(printf '%s' "$INPUT" | jq -r '.name // "AZCLIGeneratedPat"')
SCOPES=$(printf '%s' "$INPUT" | jq -r '.scopes // "vso.packaging_manage"')

if [ -z "$ORG" ] || [ "$ORG" = "null" ]; then
  echo "Error: .org is required" >&2
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
