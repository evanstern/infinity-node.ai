#!/bin/bash
set -euo pipefail

# delete-secret.sh - Delete a secret from Vaultwarden via CLI
#
# By default, deletes secrets from the "infinity-node" organization.
# Use --personal flag to delete from personal vault instead.
#
# Usage:
#   ./scripts/delete-secret.sh [--personal] <item-name> <collection-name>
#
# Examples:
#   ./scripts/delete-secret.sh "my-api-key" "vm-103-misc"
#   ./scripts/delete-secret.sh "old-secret" "shared"
#   ./scripts/delete-secret.sh --personal "personal-key" "my-folder"
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
warn() { echo -e "${YELLOW}WARNING: $1${NC}"; }

# Parse flags
USE_PERSONAL=false
if [ "${1:-}" = "--personal" ]; then
    USE_PERSONAL=true
    shift
fi

# Validate arguments
if [ $# -lt 2 ]; then
    error "Missing required arguments"
    echo "Usage: $0 [--personal] <item-name> <collection-name>"
    echo ""
    echo "Examples:"
    echo "  $0 \"api-key\" \"vm-103-misc\""
    echo "  $0 \"old-secret\" \"shared\""
    echo "  $0 --personal \"personal-key\" \"my-folder\""
    exit 1
fi

ITEM_NAME="$1"
COLLECTION_NAME="$2"

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

    # Find the item
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

    # Find the item
    info "Looking up item: $ITEM_NAME"
    ITEM_ID=$(bw list items --organizationid "$ORGANIZATION_ID" | \
        jq -r ".[] | select(.name == \"$ITEM_NAME\" and (.collectionIds[]? == \"$COLLECTION_ID\")) | .id")
fi

if [ -z "$ITEM_ID" ]; then
    error "Item '$ITEM_NAME' not found in '$COLLECTION_NAME'"
    exit 1
fi

success "Found item: $ITEM_NAME (ID: $ITEM_ID)"

# Show item details before deletion
echo ""
echo "Item to be deleted:"
bw get item "$ITEM_ID" | jq '{
    name: .name,
    folder: .folderId,
    fields: [.fields[]? | .name]
}'
echo ""

# Confirm deletion
warn "Are you sure you want to delete '$ITEM_NAME'? This cannot be undone."
read -p "Type 'yes' to confirm: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    info "Deletion cancelled"
    exit 0
fi

# Delete the item
info "Deleting item from Vaultwarden..."

if bw delete item "$ITEM_ID" > /dev/null 2>&1; then
    success "Secret '$ITEM_NAME' deleted successfully"

    # Sync to ensure deletion is propagated
    info "Syncing vault..."
    bw sync > /dev/null 2>&1
    success "Vault synced"
else
    error "Failed to delete secret"
    exit 1
fi
