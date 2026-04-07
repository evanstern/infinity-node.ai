#!/usr/bin/env bash
# docker-cleanup.sh - Clean up unused Docker images on a remote VM and report results
#
# Usage:
#   ./docker-cleanup.sh <vm-host> [ssh-user]
#
# Examples:
#   ./docker-cleanup.sh vm-103.local.infinity-node.win
#   ./docker-cleanup.sh vm-103.local.infinity-node.win evan
#
# Description:
#   Connects to a remote VM via SSH and removes all unused Docker images.
#   Reports before/after disk usage, Docker stats, and space recovered.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default SSH user
SSH_USER="${2:-evan}"

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <vm-host> [ssh-user]"
    echo ""
    echo "Examples:"
    echo "  $0 vm-103.local.infinity-node.win"
    echo "  $0 vm-103.local.infinity-node.win evan"
    exit 1
fi

VM_HOST="$1"

# Print section header
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Print subsection
print_subsection() {
    echo ""
    echo -e "${CYAN}>>> $1${NC}"
}

# Print success message
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Print error message
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Verify SSH connectivity
print_header "Connecting to $VM_HOST"
if ! ssh -o ConnectTimeout=5 "$SSH_USER@$VM_HOST" "echo 'Connection successful'" &>/dev/null; then
    print_error "Cannot connect to $SSH_USER@$VM_HOST"
    exit 1
fi
print_success "Connected to $SSH_USER@$VM_HOST"

# Get VM hostname
VM_HOSTNAME=$(ssh "$SSH_USER@$VM_HOST" "hostname" 2>/dev/null || echo "unknown")
echo "Hostname: $VM_HOSTNAME"

# Check if Docker is available
print_subsection "Checking Docker availability"
if ! ssh "$SSH_USER@$VM_HOST" "command -v docker &>/dev/null"; then
    print_warning "Docker is not installed on $VM_HOST"
    exit 0
fi
print_success "Docker is available"

# Capture BEFORE state
print_header "BEFORE Cleanup - Current State"

print_subsection "Disk Usage"
BEFORE_DF=$(ssh "$SSH_USER@$VM_HOST" "df -h /" 2>/dev/null)
echo "$BEFORE_DF"

# Extract disk usage info
BEFORE_USED=$(echo "$BEFORE_DF" | tail -1 | awk '{print $3}')
BEFORE_AVAIL=$(echo "$BEFORE_DF" | tail -1 | awk '{print $4}')
BEFORE_PERCENT=$(echo "$BEFORE_DF" | tail -1 | awk '{print $5}')

print_subsection "Docker System Info"
BEFORE_DOCKER=$(ssh "$SSH_USER@$VM_HOST" "sudo docker system df" 2>/dev/null)
echo "$BEFORE_DOCKER"

# Extract Docker image info
BEFORE_IMAGES_LINE=$(echo "$BEFORE_DOCKER" | grep "^Images")
BEFORE_IMAGE_COUNT=$(echo "$BEFORE_IMAGES_LINE" | awk '{print $2}')
BEFORE_IMAGE_SIZE=$(echo "$BEFORE_IMAGES_LINE" | awk '{print $4}')
BEFORE_RECLAIMABLE=$(echo "$BEFORE_IMAGES_LINE" | awk '{print $6}')

# Perform cleanup
print_header "Performing Docker Image Cleanup"
print_warning "Removing all unused Docker images..."

# Run docker image prune with force flag
CLEANUP_OUTPUT=$(ssh "$SSH_USER@$VM_HOST" "sudo docker image prune -a -f" 2>&1)

# Count how many images were deleted
DELETED_COUNT=$(echo "$CLEANUP_OUTPUT" | grep -c "^deleted:" || true)
UNTAGGED_COUNT=$(echo "$CLEANUP_OUTPUT" | grep -c "^untagged:" || true)

# Ensure counts are numeric (grep -c returns 0 if no matches)
DELETED_COUNT=${DELETED_COUNT:-0}
UNTAGGED_COUNT=${UNTAGGED_COUNT:-0}

if [ "$DELETED_COUNT" -eq 0 ] && [ "$UNTAGGED_COUNT" -eq 0 ]; then
    print_success "No unused images to clean up"
else
    print_success "Deleted $DELETED_COUNT images, untagged $UNTAGGED_COUNT images"
fi

# Capture AFTER state
print_header "AFTER Cleanup - New State"

print_subsection "Disk Usage"
AFTER_DF=$(ssh "$SSH_USER@$VM_HOST" "df -h /" 2>/dev/null)
echo "$AFTER_DF"

# Extract disk usage info
AFTER_USED=$(echo "$AFTER_DF" | tail -1 | awk '{print $3}')
AFTER_AVAIL=$(echo "$AFTER_DF" | tail -1 | awk '{print $4}')
AFTER_PERCENT=$(echo "$AFTER_DF" | tail -1 | awk '{print $5}')

print_subsection "Docker System Info"
AFTER_DOCKER=$(ssh "$SSH_USER@$VM_HOST" "sudo docker system df" 2>/dev/null)
echo "$AFTER_DOCKER"

# Extract Docker image info
AFTER_IMAGES_LINE=$(echo "$AFTER_DOCKER" | grep "^Images")
AFTER_IMAGE_COUNT=$(echo "$AFTER_IMAGES_LINE" | awk '{print $2}')
AFTER_IMAGE_SIZE=$(echo "$AFTER_IMAGES_LINE" | awk '{print $4}')
AFTER_RECLAIMABLE=$(echo "$AFTER_IMAGES_LINE" | awk '{print $6}')

# Generate summary report
print_header "CLEANUP SUMMARY - $VM_HOSTNAME ($VM_HOST)"

echo ""
echo -e "${CYAN}Disk Usage:${NC}"
echo "  Before: $BEFORE_USED used, $BEFORE_AVAIL available ($BEFORE_PERCENT full)"
echo "  After:  $AFTER_USED used, $AFTER_AVAIL available ($AFTER_PERCENT full)"

# Convert percentages to numbers for comparison
BEFORE_PCT=$(echo "$BEFORE_PERCENT" | tr -d '%')
AFTER_PCT=$(echo "$AFTER_PERCENT" | tr -d '%')
PCT_CHANGE=$((BEFORE_PCT - AFTER_PCT))

if [ "$PCT_CHANGE" -gt 0 ]; then
    echo -e "  ${GREEN}Change: Freed ${PCT_CHANGE}% of disk space${NC}"
elif [ "$PCT_CHANGE" -lt 0 ]; then
    echo -e "  ${YELLOW}Change: Used ${PCT_CHANGE#-}% more space (unexpected)${NC}"
else
    echo -e "  ${YELLOW}Change: No measurable change${NC}"
fi

echo ""
echo -e "${CYAN}Docker Images:${NC}"
echo "  Before: $BEFORE_IMAGE_COUNT images, $BEFORE_IMAGE_SIZE total, $BEFORE_RECLAIMABLE reclaimable"
echo "  After:  $AFTER_IMAGE_COUNT images, $AFTER_IMAGE_SIZE total, $AFTER_RECLAIMABLE reclaimable"

IMAGES_REMOVED=$((BEFORE_IMAGE_COUNT - AFTER_IMAGE_COUNT))
if [ "$IMAGES_REMOVED" -gt 0 ]; then
    echo -e "  ${GREEN}Removed: $IMAGES_REMOVED unused images${NC}"
else
    echo -e "  ${YELLOW}Removed: No images removed${NC}"
fi

echo ""
print_success "Cleanup complete!"
