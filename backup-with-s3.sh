#!/bin/bash

###############################################################################
# PostgreSQL Backup with Automatic S3 Upload
# Description: Wrapper script that runs backup and uploads to S3
# Usage: ./backup-with-s3.sh
#        Or via cron: 0 2 * * * /path/to/backup-with-s3.sh
###############################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/backup-wrapper_$(date +%Y%m%d).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

# Ensure log directory exists
mkdir -p "${SCRIPT_DIR}/logs"

log "=== Starting PostgreSQL Backup with S3 Upload ==="

# Check if containers are running
if ! docker ps | grep -q "postgres-18"; then
    log_error "postgres-18 container is not running"
    exit 1
fi

if ! docker ps | grep -q "postgres-backup-manager"; then
    log_error "postgres-backup-manager container is not running"
    exit 1
fi

log "Both containers are running ✓"

# Step 1: Run PostgreSQL backup
log "Step 1: Creating PostgreSQL backup..."
if docker exec postgres-18 /backup-scripts/backup.sh >> "$LOG_FILE" 2>&1; then
    log_success "Local backup completed"
else
    log_error "Backup failed. Check logs at: $LOG_FILE"
    exit 1
fi

# Step 2: Get the latest backup file
log "Step 2: Finding latest backup file..."
LATEST_BACKUP=$(docker exec postgres-18 ls -t /backups/daily/ 2>/dev/null | head -1)

if [ -z "$LATEST_BACKUP" ]; then
    log_error "No backup file found in /backups/daily/"
    exit 1
fi

BACKUP_PATH="/backups/daily/$LATEST_BACKUP"
log "Latest backup: $BACKUP_PATH"

# Step 3: Upload to S3
log "Step 3: Uploading to S3..."
if docker exec postgres-backup-manager /s3-scripts/upload-to-s3.sh "$BACKUP_PATH" >> "$LOG_FILE" 2>&1; then
    log_success "S3 upload completed"
else
    log_warning "S3 upload failed, but local backup is safe at: $BACKUP_PATH"
    log_warning "You can manually upload later with:"
    log_warning "  docker exec postgres-backup-manager /s3-scripts/upload-to-s3.sh $BACKUP_PATH"
    exit 1
fi

# Step 4: Verify S3 upload
log "Step 4: Verifying S3 upload..."
S3_BUCKET=$(grep S3_BUCKET_NAME "${SCRIPT_DIR}/.env" | cut -d '=' -f2)
S3_PREFIX=$(grep S3_BACKUP_PREFIX "${SCRIPT_DIR}/.env" | cut -d '=' -f2)

if docker exec postgres-backup-manager aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/daily/${LATEST_BACKUP}" >/dev/null 2>&1; then
    log_success "S3 backup verified: s3://${S3_BUCKET}/${S3_PREFIX}/daily/${LATEST_BACKUP}"
else
    log_warning "Cannot verify S3 upload"
fi

# Summary
log "=== Backup Summary ==="
log "Local backup: $BACKUP_PATH"
log "S3 backup: s3://${S3_BUCKET}/${S3_PREFIX}/daily/${LATEST_BACKUP}"
log "Log file: $LOG_FILE"
log "=== Backup Process Completed Successfully ==="

exit 0
