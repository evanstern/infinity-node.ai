#!/bin/bash
set -euo pipefail

# create-secret.sh - Helper script to create secrets in Vaultwarden via CLI
#
# By default, creates secrets in the "infinity-node" organization.
# Use --personal flag to create in personal vault instead.
#
# Usage:
#   ./scripts/create-secret.sh [--personal] <item-name> <collection-name> <password> [custom-fields-json]
#
# Examples:
#   # Organization secret (default)
#   ./scripts/create-secret.sh "my-api-key" "vm-103-misc" "secret123"
#
#   # Organization secret with custom fields
#   ./scripts/create-secret.sh "paperless-secrets" "vm-103-misc" "" \
#     '{"service":"paperless-ngx","vm":"103","postgres_password":"pass123"}'
#
#   # Personal vault secret
#   ./scripts/create-secret.sh --personal "personal-key" "my-folder" "secret123"
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
if [ "$1" = "--personal" ]; then
    USE_PERSONAL=true
    shift
fi

# Validate arguments
if [ $# -lt 3 ]; then
    error "Missing required arguments"
    echo "Usage: $0 [--personal] <item-name> <collection-name> <password> [custom-fields-json]"
    echo ""
    echo "Examples:"
    echo "  $0 \"api-key\" \"vm-103-misc\" \"secret123\""
    echo "  $0 \"multi-secret\" \"vm-103-misc\" \"\" '{\"field1\":\"value1\"}'"
    echo "  $0 --personal \"personal-key\" \"my-folder\" \"secret123\""
    exit 1
fi

ITEM_NAME="$1"
COLLECTION_NAME="$2"
PASSWORD="$3"
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
        error "Personal folder '$COLLECTION_NAME' not found. Create it first in Vaultwarden."
        echo ""
        echo "Available personal folders:"
        bw list folders | jq -r '.[].name' | sed 's/^/  - /'
        exit 1
    fi

    success "Found personal folder: $COLLECTION_NAME (ID: $FOLDER_ID)"
    ORGANIZATION_ID=""
    COLLECTION_ID=""
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
    FOLDER_ID=""
fi

# Check if item already exists
info "Checking if item already exists..."
if [ -n "$FOLDER_ID" ]; then
    EXISTING_ITEM=$(bw list items | jq -r ".[] | select(.name == \"$ITEM_NAME\" and .folderId == \"$FOLDER_ID\") | .id")
else
    EXISTING_ITEM=$(bw list items --organizationid "$ORGANIZATION_ID" | \
        jq -r ".[] | select(.name == \"$ITEM_NAME\" and (.collectionIds[]? == \"$COLLECTION_ID\")) | .id")
fi

if [ -n "$EXISTING_ITEM" ]; then
    error "Item '$ITEM_NAME' already exists in '$COLLECTION_NAME'"
    echo "  Item ID: $EXISTING_ITEM"
    echo "  Use 'bw get item $EXISTING_ITEM' to view or delete it first"
    exit 1
fi

# Build the item JSON
info "Creating item template..."

if [ "$USE_PERSONAL" = true ]; then
    # Personal vault item
    ITEM_JSON=$(bw get template item | jq \
        --arg name "$ITEM_NAME" \
        --arg folderId "$FOLDER_ID" \
        --arg password "$PASSWORD" \
        '.name = $name |
         .folderId = $folderId |
         .type = 1 |
         .login.username = "" |
         .login.password = $password')
else
    # Organization item
    ITEM_JSON=$(bw get template item | jq \
        --arg name "$ITEM_NAME" \
        --arg organizationId "$ORGANIZATION_ID" \
        --arg password "$PASSWORD" \
        --argjson collectionIds "[\"$COLLECTION_ID\"]" \
        '.name = $name |
         .organizationId = $organizationId |
         .collectionIds = $collectionIds |
         .type = 1 |
         .login.username = "" |
         .login.password = $password')
fi

# Add custom fields if provided
if [ -n "$CUSTOM_FIELDS" ]; then
    info "Adding custom fields..."

    # Convert custom fields JSON to Bitwarden field format
    FIELDS=$(echo "$CUSTOM_FIELDS" | jq -r 'to_entries | map({
        name: .key,
        value: .value,
        type: 0
    })')

    ITEM_JSON=$(echo "$ITEM_JSON" | jq --argjson fields "$FIELDS" '.fields = $fields')
fi

# Create the item
info "Creating item in Vaultwarden..."

if echo "$ITEM_JSON" | bw encode | bw create item > /dev/null 2>&1; then
    if [ "$USE_PERSONAL" = true ]; then
        success "Secret '$ITEM_NAME' created successfully in personal folder '$COLLECTION_NAME'"
    else
        success "Secret '$ITEM_NAME' created successfully in organization collection '$COLLECTION_NAME'"
    fi

    # Sync to ensure it's available
    info "Syncing vault..."
    bw sync > /dev/null 2>&1
    success "Vault synced"

    # Show the created item (without password)
    echo ""
    echo "Created item:"
    if [ "$USE_PERSONAL" = true ]; then
        bw list items | jq ".[] | select(.name == \"$ITEM_NAME\" and .folderId == \"$FOLDER_ID\") | {
            name: .name,
            folder: .folderId,
            fields: [.fields[]? | {name: .name, value: .value}]
        }"
    else
        bw list items --organizationid "$ORGANIZATION_ID" | jq ".[] | select(.name == \"$ITEM_NAME\") | {
            name: .name,
            organization: .organizationId,
            collections: .collectionIds,
            fields: [.fields[]? | {name: .name, value: .value}]
        }"
    fi
else
    error "Failed to create secret"
    exit 1
fi
