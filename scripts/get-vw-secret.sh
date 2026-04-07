#!/bin/bash
#
# get-vw-secret.sh
#
# Purpose: Retrieve a secret value from Vaultwarden
#
# This is a generic utility script for retrieving secrets from Vaultwarden.
# Can retrieve the password or any custom field.
#
# Usage:
#   ./get-vw-secret.sh <secret-name> <collection-name> [field-name]
#
# Arguments:
#   secret-name: Name of the secret item in Vaultwarden
#   collection-name: Collection containing the secret
#   field-name: (Optional) Custom field to retrieve. Default: "password"
#
# Examples:
#   # Get password
#   ./get-vw-secret.sh "hel-proxmox" "shared"
#
#   # Get custom field
#   ./get-vw-secret.sh "hel-proxmox" "shared" "url"
#
#   # Use in scripts
#   TOKEN=$(./get-vw-secret.sh "hel-proxmox" "shared")
#   URL=$(./get-vw-secret.sh "hel-proxmox" "shared" "url")
#
# Requirements:
#   - Bitwarden CLI (bw) installed
#   - BW_SESSION set: export BW_SESSION=$(cat ~/.bw-session)
#   - jq installed
#
# Exit Codes:
#   0 - Success
#   1 - Missing prerequisites or invalid arguments
#   2 - Secret or collection not found
#   3 - Field not found

set -euo pipefail

# Validate arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <secret-name> <collection-name> [field-name]" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  $0 \"hel-proxmox\" \"shared\"" >&2
    echo "  $0 \"hel-proxmox\" \"shared\" \"url\"" >&2
    exit 1
fi

SECRET_NAME="$1"
COLLECTION_NAME="$2"
FIELD_NAME="${3:-password}"

# Check prerequisites
if ! command -v bw &> /dev/null; then
    echo "ERROR: Bitwarden CLI not found" >&2
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "ERROR: jq not found" >&2
    exit 1
fi

if [ -z "${BW_SESSION:-}" ]; then
    echo "ERROR: BW_SESSION not set" >&2
    echo "Set up session first:" >&2
    echo "  export BW_SESSION=\$(cat ~/.bw-session)" >&2
    exit 1
fi

# Get organization ID
ORG_ID=$(bw list organizations 2>/dev/null | jq -r '.[] | select(.name == "infinity-node") | .id')

if [ -z "$ORG_ID" ]; then
    echo "ERROR: Organization 'infinity-node' not found" >&2
    exit 2
fi

# Get collection ID
COLLECTION_ID=$(bw list org-collections --organizationid "$ORG_ID" 2>/dev/null | \
    jq -r ".[] | select(.name == \"$COLLECTION_NAME\") | .id")

if [ -z "$COLLECTION_ID" ]; then
    echo "ERROR: Collection '$COLLECTION_NAME' not found" >&2
    exit 2
fi

# Get the secret item
SECRET_ITEM=$(bw list items --organizationid "$ORG_ID" 2>/dev/null | \
    jq -r ".[] | select(.name == \"$SECRET_NAME\" and (.collectionIds[]? == \"$COLLECTION_ID\"))")

if [ -z "$SECRET_ITEM" ]; then
    echo "ERROR: Secret '$SECRET_NAME' not found in collection '$COLLECTION_NAME'" >&2
    exit 2
fi

# Retrieve the requested field
if [ "$FIELD_NAME" = "password" ]; then
    # Get password from login.password field
    VALUE=$(echo "$SECRET_ITEM" | jq -r '.login.password')
else
    # Get custom field
    VALUE=$(echo "$SECRET_ITEM" | jq -r ".fields[]? | select(.name == \"$FIELD_NAME\") | .value")
fi

if [ -z "$VALUE" ] || [ "$VALUE" = "null" ]; then
    echo "ERROR: Field '$FIELD_NAME' not found in secret '$SECRET_NAME'" >&2
    exit 3
fi

# Output the value (no newline for easy piping)
echo -n "$VALUE"
exit 0
