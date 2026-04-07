#!/usr/bin/env bash
# check-vm-disk-space.sh - Monitor disk space across all infinity-node VMs
#
# Checks disk usage on all VMs and highlights potential issues.
# Useful for proactive monitoring before space becomes critical.
#
# Usage:
#   ./check-vm-disk-space.sh [--threshold PERCENT]
#
# Options:
#   --threshold PERCENT    Warning threshold (default: 80)
#
# Exit codes:
#   0 - All VMs have sufficient space
#   1 - One or more VMs above warning threshold
#   2 - One or more VMs critically low (>95%)

set -euo pipefail

# Configuration
WARN_THRESHOLD=80
CRITICAL_THRESHOLD=95

# VM list (DNS names)
VMS=(
    "vm-100.local.infinity-node.win:VM-100-emby"
    "vm-101.local.infinity-node.win:VM-101-downloads"
    "vm-102.local.infinity-node.win:VM-102-arr"
    "vm-103.local.infinity-node.win:VM-103-misc"
)

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --threshold)
            WARN_THRESHOLD="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--threshold PERCENT]"
            exit 1
            ;;
    esac
done

echo "=== Infinity-Node VM Disk Space Report ==="
echo "Warning threshold: ${WARN_THRESHOLD}%"
echo "Critical threshold: ${CRITICAL_THRESHOLD}%"
echo ""

WARN_COUNT=0
CRITICAL_COUNT=0

for vm_entry in "${VMS[@]}"; do
    IFS=':' read -r ip name <<< "$vm_entry"

    echo -e "${BLUE}Checking $name ($ip)${NC}"

    # Get disk usage via SSH
    if ! disk_info=$(ssh -o ConnectTimeout=5 evan@"$ip" "df -h / | tail -1" 2>&1); then
        echo -e "  ${RED}✗ Failed to connect${NC}"
        ((CRITICAL_COUNT++))
        echo ""
        continue
    fi

    # Parse disk usage
    used_percent=$(echo "$disk_info" | awk '{print $5}' | tr -d '%')
    size=$(echo "$disk_info" | awk '{print $2}')
    used=$(echo "$disk_info" | awk '{print $3}')
    avail=$(echo "$disk_info" | awk '{print $4}')

    # Determine status
    if [ "$used_percent" -ge "$CRITICAL_THRESHOLD" ]; then
        echo -e "  ${RED}✗ CRITICAL${NC} - ${used_percent}% used ($used / $size, $avail available)"
        ((CRITICAL_COUNT++))
    elif [ "$used_percent" -ge "$WARN_THRESHOLD" ]; then
        echo -e "  ${YELLOW}⚠ WARNING${NC} - ${used_percent}% used ($used / $size, $avail available)"
        ((WARN_COUNT++))
    else
        echo -e "  ${GREEN}✓ OK${NC} - ${used_percent}% used ($used / $size, $avail available)"
    fi

    # Show top disk consumers if above warning threshold
    if [ "$used_percent" -ge "$WARN_THRESHOLD" ]; then
        echo "  Top disk consumers:"
        ssh evan@"$ip" "sudo du -sh /var/lib/docker /home /var/log 2>/dev/null | sort -rh | head -3 | sed 's/^/    /'" || true
    fi

    echo ""
done

# Summary
echo "=== Summary ==="
if [ "$CRITICAL_COUNT" -gt 0 ]; then
    echo -e "${RED}Critical: $CRITICAL_COUNT VMs need immediate attention${NC}"
    exit 2
elif [ "$WARN_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}Warning: $WARN_COUNT VMs above ${WARN_THRESHOLD}% threshold${NC}"
    exit 1
else
    echo -e "${GREEN}All VMs have sufficient disk space${NC}"
    exit 0
fi
