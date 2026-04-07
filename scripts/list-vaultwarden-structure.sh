#!/bin/bash
#
# list-vaultwarden-structure.sh
#
# Purpose: Display Vaultwarden collection structure and item counts
#
# This script helps understand the organization of secrets in Vaultwarden
# by listing all collections in the infinity-node organization and the
# number of items in each.
#
# Usage:
#   ./list-vaultwarden-structure.sh
#
# Requirements:
#   - Bitwarden CLI (bw) installed
#   - Active BW_SESSION (run: export BW_SESSION=$(bw unlock --raw))
#     Or use: export BW_SESSION=$(cat ~/.bw-session) if using bw-setup-session.sh
#
# Exit Codes:
#   0 - Success
#   1 - BW_SESSION not set or bw not available
#   2 - Failed to sync or retrieve data

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if BW_SESSION is set
if [ -z "${BW_SESSION:-}" ]; then
    echo "Error: BW_SESSION not set"
    echo ""
    echo "Please unlock Bitwarden first:"
    echo "  export BW_SESSION=\$(bw unlock --raw)"
    echo ""
    echo "Or if using bw-setup-session.sh:"
    echo "  export BW_SESSION=\$(cat ~/.bw-session)"
    exit 1
fi

# Check if bw is available
if ! command -v bw &> /dev/null; then
    echo "Error: Bitwarden CLI (bw) not found"
    echo "Install from: https://bitwarden.com/help/cli/"
    exit 1
fi

echo -e "${BLUE}=== Vaultwarden Collection Structure ===${NC}"
echo ""

# Sync first to get latest data
echo "Syncing with Vaultwarden..."
if ! bw sync > /dev/null 2>&1; then
    echo -e "${YELLOW}Warning: Sync failed, using cached data${NC}"
fi
echo ""

# Get organization ID for infinity-node
ORG_ID=$(bw list organizations 2>/dev/null | jq -r '.[] | select(.name == "infinity-node") | .id')

if [ -z "$ORG_ID" ]; then
    echo -e "${YELLOW}Warning: 'infinity-node' organization not found${NC}"
    echo "Available organizations:"
    bw list organizations 2>/dev/null | jq -r '.[].name'
    exit 1
fi

echo -e "${GREEN}Organization: infinity-node${NC}"
echo -e "Organization ID: ${ORG_ID}"
echo ""

# Get all collections
COLLECTIONS=$(bw list org-collections --organizationid "$ORG_ID" 2>/dev/null || echo "[]")

if [ "$COLLECTIONS" = "[]" ] || [ -z "$COLLECTIONS" ]; then
    echo "No collections found in infinity-node organization"
    exit 0
fi

# Get all org items once
ALL_ITEMS=$(bw list items --organizationid "$ORG_ID" 2>/dev/null)

# Parse and display collections
echo -e "${GREEN}Collections:${NC}"
echo "$COLLECTIONS" | jq -r '.[] | "\(.id)|\(.name)"' | sort -t'|' -k2 | while IFS='|' read -r collection_id collection_name; do
    # Filter items that belong to this collection
    COLLECTION_ITEMS=$(echo "$ALL_ITEMS" | jq --arg cid "$collection_id" '[.[] | select(.collectionIds | index($cid))]')
    ITEM_COUNT=$(echo "$COLLECTION_ITEMS" | jq 'length')

    echo -e "  ${BLUE}${collection_name}${NC}"
    echo -e "    Collection ID: ${collection_id}"
    echo -e "    Items: ${ITEM_COUNT}"

    # List items in collection (names only)
    if [ "$ITEM_COUNT" -gt 0 ]; then
        echo -e "    Secrets:"
        echo "$COLLECTION_ITEMS" | jq -r '.[].name' | sort | while read -r item_name; do
            echo -e "      - ${item_name}"
        done
    fi
    echo ""
done

echo -e "${GREEN}=== Summary ===${NC}"
TOTAL_COLLECTIONS=$(echo "$COLLECTIONS" | jq length)
TOTAL_ORG_ITEMS=$(bw list items --organizationid "$ORG_ID" 2>/dev/null | jq length)
echo "Total Collections: $TOTAL_COLLECTIONS"
echo "Total Items in Organization: $TOTAL_ORG_ITEMS"
