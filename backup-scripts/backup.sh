#!/bin/bash

###############################################################################
# PostgreSQL Backup Script with Rotation
# Author: Auto-generated
# Description: Automated backup with daily, weekly, monthly retention
###############################################################################

# Configuration
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
LOG_DIR="${LOG_DIR:-/logs}"

# Retention days
DAILY_RETENTION=7
WEEKLY_RETENTION=30
MONTHLY_RETENTION=365

# Timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DATE=$(date +"%Y%m%d")
DAY_OF_WEEK=$(date +"%u")  # 1=Monday, 7=Sunday
DAY_OF_MONTH=$(date +"%d")

# Log file
LOG_FILE="${LOG_DIR}/backup_${DATE}.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to send notification (customize as needed)
send_notification() {
    local status=$1
    local message=$2
    log_message "NOTIFICATION: [$status] $message"
    # Add your notification method here (email, slack, etc)
}

# Start backup
log_message "=== Starting PostgreSQL Backup ==="
log_message "Host: $POSTGRES_HOST"
log_message "Database: $POSTGRES_DB"

# Create backup directories if they don't exist
mkdir -p "${BACKUP_DIR}/daily"
mkdir -p "${BACKUP_DIR}/weekly"
mkdir -p "${BACKUP_DIR}/monthly"
mkdir -p "${LOG_DIR}"

# Determine backup type
if [ "$DAY_OF_MONTH" = "01" ]; then
    BACKUP_TYPE="monthly"
    BACKUP_PATH="${BACKUP_DIR}/monthly"
elif [ "$DAY_OF_WEEK" = "7" ]; then
    BACKUP_TYPE="weekly"
    BACKUP_PATH="${BACKUP_DIR}/weekly"
else
    BACKUP_TYPE="daily"
    BACKUP_PATH="${BACKUP_DIR}/daily"
fi

BACKUP_FILE="${BACKUP_PATH}/backup_${POSTGRES_DB}_${TIMESTAMP}.dump"

log_message "Backup type: $BACKUP_TYPE"
log_message "Backup file: $BACKUP_FILE"

# Perform backup using pg_dump
log_message "Starting pg_dump..."

if [ "$POSTGRES_DB" = "all" ]; then
    # Backup all databases
    PGPASSWORD="$POSTGRES_PASSWORD" pg_dumpall \
        -h "$POSTGRES_HOST" \
        -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" \
        | gzip > "${BACKUP_FILE}.gz"
else
    # Backup single database
    PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
        -h "$POSTGRES_HOST" \
        -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" \
        -F c \
        -Z 9 \
        -f "$BACKUP_FILE"
fi

# Check if backup was successful
if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" 2>/dev/null | cut -f1)
    if [ -z "$BACKUP_SIZE" ]; then
        BACKUP_SIZE=$(du -h "${BACKUP_FILE}.gz" 2>/dev/null | cut -f1)
        BACKUP_FILE="${BACKUP_FILE}.gz"
    fi
    log_message "Backup completed successfully! Size: $BACKUP_SIZE"
    send_notification "SUCCESS" "Backup completed: $BACKUP_FILE"

    # Note: S3 upload handled by wrapper script (backup-with-s3.sh)
    # If running standalone, upload manually:
    #   docker exec postgres-backup-manager /s3-scripts/upload-to-s3.sh $BACKUP_FILE
else
    log_message "ERROR: Backup failed!"
    send_notification "ERROR" "Backup failed for database: $POSTGRES_DB"
    exit 1
fi

# Cleanup old backups based on retention policy
log_message "=== Cleaning up old backups ==="

# Cleanup daily backups
log_message "Removing daily backups older than $DAILY_RETENTION days..."
find "${BACKUP_DIR}/daily" -name "backup_*.dump" -type f -mtime +$DAILY_RETENTION -delete
find "${BACKUP_DIR}/daily" -name "backup_*.dump.gz" -type f -mtime +$DAILY_RETENTION -delete

# Cleanup weekly backups
log_message "Removing weekly backups older than $WEEKLY_RETENTION days..."
find "${BACKUP_DIR}/weekly" -name "backup_*.dump" -type f -mtime +$WEEKLY_RETENTION -delete
find "${BACKUP_DIR}/weekly" -name "backup_*.dump.gz" -type f -mtime +$WEEKLY_RETENTION -delete

# Cleanup monthly backups
log_message "Removing monthly backups older than $MONTHLY_RETENTION days..."
find "${BACKUP_DIR}/monthly" -name "backup_*.dump" -type f -mtime +$MONTHLY_RETENTION -delete
find "${BACKUP_DIR}/monthly" -name "backup_*.dump.gz" -type f -mtime +$MONTHLY_RETENTION -delete

# Cleanup old logs
log_message "Removing logs older than 30 days..."
find "${LOG_DIR}" -name "backup_*.log" -type f -mtime +30 -delete

# Summary
log_message "=== Backup Summary ==="
log_message "Daily backups: $(ls -1 ${BACKUP_DIR}/daily | wc -l)"
log_message "Weekly backups: $(ls -1 ${BACKUP_DIR}/weekly | wc -l)"
log_message "Monthly backups: $(ls -1 ${BACKUP_DIR}/monthly | wc -l)"
log_message "=== Backup Process Completed ==="

exit 0
