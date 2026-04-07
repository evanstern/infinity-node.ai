#!/usr/bin/env bash
# backup-vaultwarden.sh - Automated Vaultwarden database backup
#
# Backs up Vaultwarden SQLite database to NAS via scp with retention policy.
# Ensures database consistency using SQLite's built-in backup command.
#
# Requirements:
#   - sqlite3
#   - scp (for file transfer over SSH)
#   - SSH key-based authentication to NAS (no password needed)
#
# Setup:
#   1. Generate SSH key if needed: ssh-keygen -t rsa -b 4096
#   2. Copy public key to NAS: ssh-copy-id backup@jace.local.infinity-node.win
#   3. Test connection: ssh backup@jace.local.infinity-node.win 'echo test'
#
# Usage:
#   ./backup-vaultwarden.sh
#
# Schedule via cron:
#   0 2 * * * /home/evan/scripts/backup-vaultwarden.sh >> /var/log/vaultwarden-backup.log 2>&1
#
# Exit codes:
#   0 - Success
#   1 - Source database not found
#   2 - Backup failed
#   3 - Backup integrity check failed
#   4 - NAS not accessible or scp failed
#   5 - Missing required tools or credentials

set -euo pipefail

# Configuration
SOURCE_DB="/home/evan/data/vw-data/db.sqlite3"
NAS_HOST="jace.local.infinity-node.win"
NAS_USER="backup"
NAS_BACKUP_DIR="backups/vaultwarden"  # Relative to Synology SFTP chroot (/volume1/)
NAS_BACKUP_DIR_FULL="/volume1/backups/vaultwarden"  # Full path for SSH commands
LOCAL_TMP_DIR="/tmp"
DATE=$(date +%Y%m%d-%H%M%S)
LOCAL_BACKUP_FILE="$LOCAL_TMP_DIR/vw-backup-$DATE.sqlite3"
REMOTE_BACKUP_FILE="vw-backup-$DATE.sqlite3"
RETENTION_DAYS=30

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
error() { echo -e "${RED}ERROR: $1${NC}" >&2; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
info() { echo -e "${YELLOW}→ $1${NC}"; }

# Start backup process
info "Starting Vaultwarden backup at $(date)"

# Verify required tools are installed
for cmd in sqlite3 scp ssh; do
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
    error "Or manually add ~/.ssh/id_rsa.pub to ${NAS_USER}@${NAS_HOST}:~/.ssh/authorized_keys"
    exit 5
fi
success "SSH key authentication verified"

# Verify source database exists
if [ ! -f "$SOURCE_DB" ]; then
    error "Source database not found: $SOURCE_DB"
    exit 1
fi

# Get source database size for logging
SOURCE_SIZE=$(du -h "$SOURCE_DB" | cut -f1)
info "Source database size: $SOURCE_SIZE"

# Create backup locally using SQLite's VACUUM INTO command (handles locks better)
# This method works even when database is in use by Vaultwarden
info "Creating local backup..."
if ! sqlite3 "$SOURCE_DB" "VACUUM INTO '$LOCAL_BACKUP_FILE'"; then
    error "SQLite backup command failed"
    error "Database may be locked. Trying alternative method..."

    # Fallback: Use cp with sync for consistency
    if cp "$SOURCE_DB" "$LOCAL_BACKUP_FILE" && sync; then
        info "Used fallback copy method"
    else
        error "Both backup methods failed"
        exit 2
    fi
fi

# Verify backup file was created
if [ ! -f "$LOCAL_BACKUP_FILE" ]; then
    error "Backup file not created: $LOCAL_BACKUP_FILE"
    exit 2
fi

# Check backup file size
BACKUP_SIZE=$(du -h "$LOCAL_BACKUP_FILE" | cut -f1)
info "Backup file size: $BACKUP_SIZE"

# Verify backup is a valid SQLite database
info "Verifying backup integrity..."
if ! sqlite3 "$LOCAL_BACKUP_FILE" "PRAGMA integrity_check;" | grep -q "ok"; then
    error "Backup integrity check failed - database may be corrupt"
    error "Backup file: $LOCAL_BACKUP_FILE"
    rm -f "$LOCAL_BACKUP_FILE"
    exit 3
fi

success "Local backup created successfully: $LOCAL_BACKUP_FILE"

# Copy backup to NAS via scp over SSH (using key authentication)
info "Uploading backup to NAS ($NAS_HOST)..."
if ! scp -o BatchMode=yes -o StrictHostKeyChecking=no "$LOCAL_BACKUP_FILE" ${NAS_USER}@${NAS_HOST}:${NAS_BACKUP_DIR}/${REMOTE_BACKUP_FILE}; then
    error "Failed to upload backup to NAS"
    rm -f "$LOCAL_BACKUP_FILE"
    exit 4
fi

success "Backup uploaded to NAS: $NAS_BACKUP_DIR_FULL/$REMOTE_BACKUP_FILE"

# Clean up local temporary file
rm -f "$LOCAL_BACKUP_FILE"
info "Cleaned up local temporary backup file"

# Cleanup old backups on NAS
info "Cleaning up backups older than $RETENTION_DAYS days on NAS..."
if ssh -o BatchMode=yes -o StrictHostKeyChecking=no ${NAS_USER}@${NAS_HOST} "find ${NAS_BACKUP_DIR_FULL} -name 'vw-backup-*.sqlite3' -mtime +${RETENTION_DAYS} -delete && find ${NAS_BACKUP_DIR_FULL} -name 'vw-backup-*.sqlite3' | wc -l" >/dev/null 2>&1; then
    success "Old backups cleaned up successfully"
else
    error "Warning: Cleanup may have failed (non-critical)"
fi

# Get backup statistics from NAS
info "Retrieving backup statistics from NAS..."
STATS=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no ${NAS_USER}@${NAS_HOST} "cd ${NAS_BACKUP_DIR_FULL} && find . -name 'vw-backup-*.sqlite3' | wc -l && du -sh ." 2>/dev/null || echo "ERROR")

success "Backup complete!"
echo ""
echo "Statistics:"
echo "  Latest backup: $NAS_BACKUP_DIR_FULL/$REMOTE_BACKUP_FILE"
echo "  Backup size: $BACKUP_SIZE"
echo "  NAS backup directory: $NAS_BACKUP_DIR_FULL"
echo "  Retention policy: $RETENTION_DAYS days"
if [ "$STATS" != "ERROR" ]; then
    echo "  Remote statistics: (use ssh to NAS for details)"
fi
echo ""

exit 0
