#!/bin/bash
#
# backup-calibre-library.sh
#
# Purpose: Backup Calibre library from VM disk to NAS
#
# This script creates a backup of the Calibre library (database + books)
# from the VM's local disk to the NAS for disaster recovery.
#
# Usage:
#   ./backup-calibre-library.sh
#
# Cron Usage:
#   # Daily at 3 AM
#   0 3 * * * /home/evan/scripts/backup-calibre-library.sh >> /var/log/calibre-backup.log 2>&1
#
# What it does:
#   1. Stops Calibre containers to ensure clean backup
#   2. Creates timestamped backup on NAS
#   3. Keeps last 7 daily backups
#   4. Restarts Calibre containers
#   5. Logs all operations
#
# Requirements:
#   - SSH key-based authentication to NAS (no password needed)
#   - Sufficient space on NAS for backups
#   - Docker access (user in docker group)
#
# Exit Codes:
#   0 - Success
#   1 - Backup failed
#   2 - Container management failed

set -euo pipefail

# Configuration
SOURCE_DIR="/home/evan/calibre-library"
NAS_HOST="jace.local.infinity-node.win"
NAS_USER="backup"
NAS_BACKUP_DIR="backups/calibre"  # Relative to Synology SFTP chroot (/volume1/)
NAS_BACKUP_DIR_FULL="/volume1/backups/calibre"  # Full path for SSH commands
LOCAL_TMP_DIR="/tmp"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="calibre-library-${DATE}.tar.gz"
LOCAL_BACKUP_FILE="${LOCAL_TMP_DIR}/${BACKUP_NAME}"
REMOTE_BACKUP_FILE="${BACKUP_NAME}"
RETENTION_DAYS=7
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${LOG_PREFIX} $1"; }
error() { echo -e "${LOG_PREFIX} ${RED}ERROR: $1${NC}" >&2; }
success() { echo -e "${LOG_PREFIX} ${GREEN}✓ $1${NC}"; }
info() { echo -e "${LOG_PREFIX} ${BLUE}→ $1${NC}"; }
warn() { echo -e "${LOG_PREFIX} ${YELLOW}⚠ $1${NC}"; }

# Verify required tools are installed
for cmd in scp ssh; do
    if ! command -v $cmd &> /dev/null; then
        error "Required command not found: $cmd"
        exit 5
    fi
done

# Verify SSH key authentication works
info "Testing SSH key authentication to NAS..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no ${NAS_USER}@${NAS_HOST} 'echo "SSH key auth OK"' >/dev/null 2>&1; then
    error "SSH key authentication failed"
    error "Setup SSH keys with: ssh-copy-id ${NAS_USER}@${NAS_HOST}"
    exit 5
fi
success "SSH key authentication verified"

# Check if source exists
if [ ! -d "$SOURCE_DIR" ]; then
    error "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Ensure NAS backup directory exists
info "Ensuring NAS backup directory exists..."
ssh -o BatchMode=yes -o StrictHostKeyChecking=no ${NAS_USER}@${NAS_HOST} "mkdir -p ${NAS_BACKUP_DIR_FULL}" || {
    error "Failed to create NAS backup directory"
    exit 1
}

# Check if Calibre containers are running
CALIBRE_RUNNING=$(docker ps --filter "name=calibre" --filter "status=running" --format "{{.Names}}" | wc -l)

if [ "$CALIBRE_RUNNING" -gt 0 ]; then
    info "Stopping Calibre containers for clean backup..."
    docker stop calibre calibre-web 2>/dev/null || {
        warn "Some containers may not have stopped cleanly"
    }
    CONTAINERS_STOPPED=true

    # Wait for filesystem to settle
    info "Waiting for filesystem to settle..."
    sleep 10
else
    info "Calibre containers not running, proceeding with backup"
    CONTAINERS_STOPPED=false
fi

# Calculate library size
LIBRARY_SIZE=$(du -sh "$SOURCE_DIR" | cut -f1)
info "Library size: $LIBRARY_SIZE"

# Create backup locally first
info "Creating backup: $BACKUP_NAME"
START_TIME=$(date +%s)

# Run tar and capture exit code
set +e # Disable exit on error for tar command
tar czf "$LOCAL_BACKUP_FILE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" 2>&1
TAR_EXIT=$?
set -e # Re-enable exit on error

# Tar exit code 1 means "some files differ" (changed during read), which is a warning.
# Tar exit code 2 means fatal error.
if [ $TAR_EXIT -ge 2 ]; then
    error "Backup creation failed (tar exit code $TAR_EXIT)"

    # Restart containers if we stopped them
    if [ "$CONTAINERS_STOPPED" = true ]; then
        warn "Restarting Calibre containers after failed backup..."
        docker start calibre calibre-web 2>/dev/null || error "Failed to restart containers"
    fi

    exit 1
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
BACKUP_SIZE=$(du -sh "$LOCAL_BACKUP_FILE" | cut -f1)

success "Local backup created: $LOCAL_BACKUP_FILE"
info "Backup size: $BACKUP_SIZE"
info "Duration: ${DURATION} seconds"

# Upload backup to NAS via scp over SSH (using key authentication)
info "Uploading backup to NAS ($NAS_HOST)..."
if ! scp -o BatchMode=yes -o StrictHostKeyChecking=no "$LOCAL_BACKUP_FILE" ${NAS_USER}@${NAS_HOST}:${NAS_BACKUP_DIR}/${REMOTE_BACKUP_FILE}; then
    error "Failed to upload backup to NAS"
    rm -f "$LOCAL_BACKUP_FILE"

    # Restart containers if we stopped them
    if [ "$CONTAINERS_STOPPED" = true ]; then
        warn "Restarting Calibre containers after failed upload..."
        docker start calibre calibre-web 2>/dev/null || error "Failed to restart containers"
    fi

    exit 1
fi

success "Backup uploaded to NAS: $NAS_BACKUP_DIR_FULL/$REMOTE_BACKUP_FILE"

# Clean up local temporary file
rm -f "$LOCAL_BACKUP_FILE"
info "Cleaned up local temporary backup file"

# Restart containers if we stopped them
if [ "$CONTAINERS_STOPPED" = true ]; then
    info "Restarting Calibre containers..."
    docker start calibre calibre-web || {
        error "Failed to restart containers"
        exit 2
    }

    # Wait a moment and verify they started
    sleep 3
    RUNNING_NOW=$(docker ps --filter "name=calibre" --filter "status=running" --format "{{.Names}}" | wc -l)
    if [ "$RUNNING_NOW" -eq 2 ]; then
        success "Calibre containers restarted successfully"
    else
        warn "Not all Calibre containers are running (${RUNNING_NOW}/2)"
    fi
fi

# Clean up old backups on NAS
info "Cleaning up backups older than $RETENTION_DAYS days on NAS..."
if ssh -o BatchMode=yes -o StrictHostKeyChecking=no ${NAS_USER}@${NAS_HOST} "find ${NAS_BACKUP_DIR_FULL} -name 'calibre-library-*.tar.gz' -mtime +${RETENTION_DAYS} -delete && find ${NAS_BACKUP_DIR_FULL} -name 'calibre-library-*.tar.gz' | wc -l" >/dev/null 2>&1; then
    success "Old backups cleaned up successfully"
else
    warn "Warning: Cleanup may have failed (non-critical)"
fi

# Get backup count from NAS
REMAINING_BACKUPS=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no ${NAS_USER}@${NAS_HOST} "find ${NAS_BACKUP_DIR_FULL} -name 'calibre-library-*.tar.gz' -type f | wc -l" 2>/dev/null || echo "0")
info "Backups retained on NAS: $REMAINING_BACKUPS"

# List recent backups from NAS
info "Recent backups on NAS:"
ssh -o BatchMode=yes -o StrictHostKeyChecking=no ${NAS_USER}@${NAS_HOST} "cd ${NAS_BACKUP_DIR_FULL} && find . -name 'calibre-library-*.tar.gz' -type f -printf '%T+ %p\n' | sort -r | head -5" 2>/dev/null | while read -r line; do
    TIMESTAMP=$(echo "$line" | cut -d' ' -f1)
    FILE=$(echo "$line" | cut -d' ' -f2- | sed 's|^\./||')
    SIZE=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no ${NAS_USER}@${NAS_HOST} "du -sh ${NAS_BACKUP_DIR_FULL}/${FILE} 2>/dev/null | cut -f1" || echo "unknown")
    log "  - $FILE ($SIZE) - $TIMESTAMP"
done || warn "Could not retrieve backup list from NAS"

success "Backup completed successfully"
exit 0
