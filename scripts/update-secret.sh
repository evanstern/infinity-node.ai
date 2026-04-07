#!/bin/bash
set -euo pipefail

# update-secret.sh - Update an existing secret in Vaultwarden via CLI
#
# By default, updates secrets in the "infinity-node" organization.
# Use --personal flag to update in personal vault instead.
#
# Usage:
#   ./scripts/update-secret.sh [--personal] <item-name> <collection-name> [password] [custom-fields-json]
#
# Examples:
#   # Update just the password (organization)
#   ./scripts/update-secret.sh "my-api-key" "vm-103-misc" "newsecret123"
#
#   # Update custom fields (preserves password if not provided)
#   ./scripts/update-secret.sh "paperless-secrets" "vm-103-misc" "" \
#     '{"postgres_password":"newpass","secret_key":"newkey"}'
#
#   # Update personal vault secret
#   ./scripts/update-secret.sh --personal "my-secret" "my-folder" "newpassword"
#
# Prerequisites:
#   - Bitwarden CLI installed (brew install bitwarden-cli)
#   - Vault unlocked: export BW_SESSION=$(bw unlock --raw)
#   - jq installed (brew install jq)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
error() { echo -e "${RED}ERROR: $1${NC}" >&2; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
info() { echo -e "${YELLOW}→ $1${NC}"; }

# Parse flags
USE_PERSONAL=false
if [ "${1:-}" = "--personal" ]; then
    USE_PERSONAL=true
    shift
fi

# Validate arguments
if [ $# -lt 2 ]; then
    error "Missing required arguments"
    echo "Usage: $0 [--personal] <item-name> <collection-name> [password] [custom-fields-json]"
    echo ""
    echo "Examples:"
    echo "  $0 \"api-key\" \"vm-103-misc\" \"newsecret123\""
    echo "  $0 \"multi-secret\" \"vm-103-misc\" \"\" '{\"field1\":\"value1\"}'"
    echo "  $0 --personal \"personal-key\" \"my-folder\" \"newsecret123\""
    exit 1
fi

ITEM_NAME="$1"
COLLECTION_NAME="$2"
NEW_PASSWORD="${3:-}"
CUSTOM_FIELDS="${4:-}"

# Check prerequisites
info "Checking prerequisites..."

if ! command -v bw &> /dev/null; then
    error "Bitwarden CLI not found. Install with: brew install bitwarden-cli"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    error "jq not found. Install with: brew install jq"
    exit 1
fi

if [ -z "${BW_SESSION:-}" ]; then
    error "Vault not unlocked. Run: export BW_SESSION=\$(bw unlock --raw)"
    exit 1
fi

# Verify vault is actually unlocked
if ! bw status | jq -e '.status == "unlocked"' > /dev/null 2>&1; then
    error "Vault is not unlocked. Run: export BW_SESSION=\$(bw unlock --raw)"
    exit 1
fi

success "Prerequisites validated"

# Determine if using organization or personal vault
if [ "$USE_PERSONAL" = true ]; then
    # Personal vault - use folders
    info "Looking up personal folder: $COLLECTION_NAME"
    FOLDER_ID=$(bw list folders | jq -r ".[] | select(.name == \"$COLLECTION_NAME\") | .id")

    if [ -z "$FOLDER_ID" ]; then
        error "Personal folder '$COLLECTION_NAME' not found."
        echo ""
        echo "Available personal folders:"
        bw list folders | jq -r '.[].name' | sed 's/^/  - /'
        exit 1
    fi

    success "Found personal folder: $COLLECTION_NAME (ID: $FOLDER_ID)"

    # Find the existing item
    info "Looking up item: $ITEM_NAME"
    ITEM_ID=$(bw list items | jq -r ".[] | select(.name == \"$ITEM_NAME\" and .folderId == \"$FOLDER_ID\") | .id")
else
    # Organization vault - use collections
    info "Looking up infinity-node organization..."
    ORG_NAME="infinity-node"
    ORGANIZATION_ID=$(bw list organizations | jq -r ".[] | select(.name == \"$ORG_NAME\") | .id")

    if [ -z "$ORGANIZATION_ID" ]; then
        error "Organization '$ORG_NAME' not found."
        echo ""
        echo "Available organizations:"
        bw list organizations | jq -r '.[].name' | sed 's/^/  - /'
        exit 1
    fi

    success "Found organization: $ORG_NAME (ID: $ORGANIZATION_ID)"

    info "Looking up collection: $COLLECTION_NAME"
    COLLECTION_ID=$(bw list org-collections --organizationid "$ORGANIZATION_ID" | \
        jq -r ".[] | select(.name == \"$COLLECTION_NAME\") | .id")

    if [ -z "$COLLECTION_ID" ]; then
        error "Collection '$COLLECTION_NAME' not found in organization '$ORG_NAME'."
        echo ""
        echo "Available collections:"
        bw list org-collections --organizationid "$ORGANIZATION_ID" | jq -r '.[].name' | sed 's/^/  - /'
        exit 1
    fi

    success "Found collection: $COLLECTION_NAME (ID: $COLLECTION_ID)"

    # Find the existing item
    info "Looking up item: $ITEM_NAME"
    ITEM_ID=$(bw list items --organizationid "$ORGANIZATION_ID" | \
        jq -r ".[] | select(.name == \"$ITEM_NAME\" and (.collectionIds[]? == \"$COLLECTION_ID\")) | .id")
fi

if [ -z "$ITEM_ID" ]; then
    error "Item '$ITEM_NAME' not found in '$COLLECTION_NAME'"
    echo "Use './scripts/create-secret.sh' to create a new item"
    exit 1
fi

success "Found item: $ITEM_NAME (ID: $ITEM_ID)"

# Get the current item
info "Fetching current item data..."
CURRENT_ITEM=$(bw get item "$ITEM_ID")

# Update password if provided
if [ -n "$NEW_PASSWORD" ]; then
    info "Updating password..."
    CURRENT_ITEM=$(echo "$CURRENT_ITEM" | jq --arg password "$NEW_PASSWORD" '.login.password = $password')
fi

# Update or merge custom fields if provided
if [ -n "$CUSTOM_FIELDS" ]; then
    info "Updating custom fields..."

    # Get existing fields
    EXISTING_FIELDS=$(echo "$CURRENT_ITEM" | jq '.fields // []')

    # Convert new custom fields JSON to Bitwarden field format
    NEW_FIELDS=$(echo "$CUSTOM_FIELDS" | jq -r 'to_entries | map({
        name: .key,
        value: .value,
        type: 0
    })')

    # Merge: keep existing fields not in new fields, add/update new fields
    MERGED_FIELDS=$(jq -n \
        --argjson existing "$EXISTING_FIELDS" \
        --argjson new "$NEW_FIELDS" \
        '$existing + $new | group_by(.name) | map(.[0])')

    CURRENT_ITEM=$(echo "$CURRENT_ITEM" | jq --argjson fields "$MERGED_FIELDS" '.fields = $fields')
fi

# Update the item
info "Updating item in Vaultwarden..."

if echo "$CURRENT_ITEM" | bw encode | bw edit item "$ITEM_ID" > /dev/null 2>&1; then
    success "Secret '$ITEM_NAME' updated successfully"

    # Sync to ensure changes are propagated
    info "Syncing vault..."
    bw sync > /dev/null 2>&1
    success "Vault synced"

    # Show the updated item (without password)
    echo ""
    echo "Updated item:"
    bw get item "$ITEM_ID" | jq '{
        name: .name,
        folder: .folderId,
        hasPassword: (.login.password != null and .login.password != ""),
        fields: [.fields[]? | {name: .name, value: .value}]
    }'
else
    error "Failed to update secret"
    exit 1
fi
