#!/bin/bash
set -euo pipefail

# manage-pihole-dns.sh - Manage Pi-hole local DNS records via API
#
# This script automates DNS record management in Pi-hole, allowing you to:
# - Add/update DNS records from a configuration file
# - Handle IP changes automatically
# - Version control DNS records in git
#
# Usage:
#   ./scripts/infrastructure/manage-pihole-dns.sh [--config CONFIG_FILE] [--dry-run]
#
# Examples:
#   # Sync all DNS records from default config
#   ./scripts/infrastructure/manage-pihole-dns.sh
#
#   # Use custom config file
#   ./scripts/infrastructure/manage-pihole-dns.sh --config dns-records.yaml
#
#   # Dry run (show what would be changed)
#   ./scripts/infrastructure/manage-pihole-dns.sh --dry-run
#
# Prerequisites:
#   - Pi-hole API token stored in Vaultwarden (shared/pihole-api-token)
#   - jq installed (brew install jq)
#   - curl installed
#   - BW_SESSION set: export BW_SESSION=$(cat ~/.bw-session)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
error() { echo -e "${RED}ERROR: $1${NC}" >&2; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
info() { echo -e "${YELLOW}→ $1${NC}"; }
debug() { echo -e "${BLUE}  $1${NC}"; }

# Default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/dns-records.json"
PIHOLE_IP="192.168.1.79"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--config CONFIG_FILE] [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --config FILE    Path to DNS records config file (default: config/dns-records.yaml)"
            echo "  --dry-run        Show what would be changed without making changes"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check prerequisites
info "Checking prerequisites..."

if ! command -v jq &> /dev/null; then
    error "jq not found. Install with: brew install jq"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    error "curl not found"
    exit 1
fi

if [ -z "${BW_SESSION:-}" ]; then
    error "Vault not unlocked. Run: export BW_SESSION=\$(cat ~/.bw-session)"
    exit 1
fi

# Get Pi-hole API token from Vaultwarden
info "Retrieving Pi-hole API token from Vaultwarden..."
PIHOLE_TOKEN=$(bw get password "pihole-api-token" 2>/dev/null || bw get item "pihole-api-token" 2>/dev/null | jq -r '.login.password // .fields[]? | select(.name=="api_token") | .value')

if [ -z "$PIHOLE_TOKEN" ] || [ "$PIHOLE_TOKEN" = "null" ]; then
    error "Failed to retrieve Pi-hole API token from Vaultwarden"
    echo ""
    echo "To get your API token:"
    echo "1. Log into Pi-hole web UI: http://${PIHOLE_IP}/admin"
    echo "2. Go to Settings → API/Web Interface"
    echo "3. Click 'Show API Token'"
    echo "4. Store in Vaultwarden: ./scripts/secrets/create-secret.sh 'pihole-api-token' 'shared' 'YOUR_TOKEN_HERE'"
    exit 1
fi

success "Retrieved Pi-hole API token"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    error "Config file not found: $CONFIG_FILE"
    echo ""
            echo "Create a DNS records config file. See config/dns-records.json for example format."
    exit 1
fi

info "Using config file: $CONFIG_FILE"

# Pi-hole API functions
pihole_api() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"

    # Try both API endpoint formats (Pi-hole version differences)
    local url1="http://${PIHOLE_IP}/admin/api.php?${endpoint}&auth=${PIHOLE_TOKEN}"
    local url2="http://${PIHOLE_IP}/api.php?${endpoint}&auth=${PIHOLE_TOKEN}"

    local result=""
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        result=$(curl -s -X POST "$url1" -d "$data" 2>&1)
        # If first URL fails, try second
        if echo "$result" | jq -e '.error' > /dev/null 2>&1; then
            result=$(curl -s -X POST "$url2" -d "$data" 2>&1)
        fi
    else
        result=$(curl -s "$url1" 2>&1)
        # If first URL fails, try second
        if echo "$result" | jq -e '.error' > /dev/null 2>&1; then
            result=$(curl -s "$url2" 2>&1)
        fi
    fi

    echo "$result"
}

# Get current DNS records from Pi-hole
get_current_records() {
    local result=$(pihole_api "list=local")

    # Check for errors
    if echo "$result" | jq -e '.error' > /dev/null 2>&1; then
        error "Pi-hole API error: $(echo "$result" | jq -r '.error.message // .error')"
        echo "$result" | jq -r '.error.hint // ""' 2>/dev/null
        return 1
    fi

    # Extract records
    echo "$result" | jq -r '.data[]? | "\(.domain)|\(.ip)"' 2>/dev/null || echo ""
}

# Add DNS record
add_dns_record() {
    local domain="$1"
    local ip="$2"

    if [ "$DRY_RUN" = true ]; then
        info "Would add: $domain → $ip"
        return 0
    fi

    local result=$(pihole_api "customdns&action=add&domain=${domain}&ip=${ip}" "GET")

    if echo "$result" | jq -e '.success == true' > /dev/null 2>&1; then
        success "Added: $domain → $ip"
        return 0
    else
        error "Failed to add $domain → $ip"
        echo "$result" | jq -r '.message // .error // "Unknown error"' 2>/dev/null || echo "$result"
        return 1
    fi
}

# Delete DNS record
delete_dns_record() {
    local domain="$1"

    if [ "$DRY_RUN" = true ]; then
        info "Would delete: $domain"
        return 0
    fi

    local result=$(pihole_api "customdns&action=delete&domain=${domain}" "GET")

    if echo "$result" | jq -e '.success == true' > /dev/null 2>&1; then
        success "Deleted: $domain"
        return 0
    else
        error "Failed to delete $domain"
        return 1
    fi
}

# Main execution
info "Fetching current DNS records from Pi-hole..."
CURRENT_RECORDS=$(get_current_records)

if [ "$DRY_RUN" = true ]; then
    info "DRY RUN MODE - No changes will be made"
    echo ""
fi

# Parse config and build desired state
info "Parsing config file: $CONFIG_FILE"
DOMAIN=$(jq -r '.domain' "$CONFIG_FILE")

if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "null" ]; then
    error "Invalid config file: domain not found"
    exit 1
fi

success "Domain: $DOMAIN"

info "Syncing DNS records..."

# Use temp files to track changes (bash subshell issue with while loops)
TEMP_CHANGES=$(mktemp)
TEMP_ERRORS=$(mktemp)
echo "0" > "$TEMP_CHANGES"
echo "0" > "$TEMP_ERRORS"

# Function to process a DNS record
process_record() {
    local domain="$1"
    local ip="$2"

    if [ -z "$domain" ] || [ -z "$ip" ]; then
        return
    fi

    # Check if record exists and matches
    existing_ip=$(echo "$CURRENT_RECORDS" | grep "^${domain}|" | cut -d'|' -f2)

    if [ -z "$existing_ip" ]; then
        # Record doesn't exist, add it
        info "Adding new record: $domain → $ip"
        if add_dns_record "$domain" "$ip"; then
            local changes=$(cat "$TEMP_CHANGES")
            echo $((changes + 1)) > "$TEMP_CHANGES"
        else
            local errors=$(cat "$TEMP_ERRORS")
            echo $((errors + 1)) > "$TEMP_ERRORS"
        fi
    elif [ "$existing_ip" != "$ip" ]; then
        # Record exists but IP changed, update it
        info "Updating record: $domain → $ip (was $existing_ip)"
        delete_dns_record "$domain"
        if add_dns_record "$domain" "$ip"; then
            local changes=$(cat "$TEMP_CHANGES")
            echo $((changes + 1)) > "$TEMP_CHANGES"
        else
            local errors=$(cat "$TEMP_ERRORS")
            echo $((errors + 1)) > "$TEMP_ERRORS"
        fi
    else
        debug "Record already correct: $domain → $ip"
    fi
}

# Process VM records
while IFS='|' read -r domain ip; do
    process_record "$domain" "$ip"
done < <(jq -r ".records.vms | to_entries[] | \"\(.key).${DOMAIN}|\(.value)\"" "$CONFIG_FILE")

# Process service records
while IFS='|' read -r domain ip; do
    process_record "$domain" "$ip"
done < <(jq -r ".records.services | to_entries[] | \"\(.key).${DOMAIN}|\(.value.ip)\"" "$CONFIG_FILE")

# Read final counts
CHANGES_MADE=$(cat "$TEMP_CHANGES")
ERRORS=$(cat "$TEMP_ERRORS")

# Cleanup temp files
rm -f "$TEMP_CHANGES" "$TEMP_ERRORS"

# Summary
echo ""
if [ "$DRY_RUN" = true ]; then
    info "Dry run complete - no changes made"
else
    if [ $ERRORS -eq 0 ]; then
        success "DNS sync complete! Changes made: $CHANGES_MADE"
    else
        error "DNS sync completed with $ERRORS error(s)"
        exit 1
    fi
fi
