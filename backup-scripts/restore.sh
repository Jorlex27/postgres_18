#!/bin/bash

###############################################################################
# PostgreSQL Restore Script
# Author: Auto-generated
# Description: Restore PostgreSQL database from backup
###############################################################################

# Configuration
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
LOG_DIR="${LOG_DIR:-/logs}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to list available backups
list_backups() {
    print_message "$YELLOW" "=== Available Backups ==="
    echo ""

    if [ -d "${BACKUP_DIR}/daily" ] && [ "$(ls -A ${BACKUP_DIR}/daily)" ]; then
        print_message "$GREEN" "DAILY Backups:"
        ls -lh "${BACKUP_DIR}/daily" | grep -v "^total" | awk '{print "  " $9 " (" $5 ", " $6 " " $7 ")"}'
        echo ""
    fi

    if [ -d "${BACKUP_DIR}/weekly" ] && [ "$(ls -A ${BACKUP_DIR}/weekly)" ]; then
        print_message "$GREEN" "WEEKLY Backups:"
        ls -lh "${BACKUP_DIR}/weekly" | grep -v "^total" | awk '{print "  " $9 " (" $5 ", " $6 " " $7 ")"}'
        echo ""
    fi

    if [ -d "${BACKUP_DIR}/monthly" ] && [ "$(ls -A ${BACKUP_DIR}/monthly)" ]; then
        print_message "$GREEN" "MONTHLY Backups:"
        ls -lh "${BACKUP_DIR}/monthly" | grep -v "^total" | awk '{print "  " $9 " (" $5 ", " $6 " " $7 ")"}'
        echo ""
    fi
}

# Function to perform restore
perform_restore() {
    local backup_file=$1

    if [ ! -f "$backup_file" ]; then
        print_message "$RED" "ERROR: Backup file not found: $backup_file"
        exit 1
    fi

    print_message "$YELLOW" "=== Starting PostgreSQL Restore ==="
    echo "Host: $POSTGRES_HOST"
    echo "Database: $POSTGRES_DB"
    echo "Backup file: $backup_file"
    echo ""

    # Warning
    print_message "$RED" "WARNING: This will overwrite the database '$POSTGRES_DB'!"
    read -p "Are you sure you want to continue? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        print_message "$YELLOW" "Restore cancelled."
        exit 0
    fi

    print_message "$YELLOW" "Starting restore process..."

    # Check if file is gzipped
    if [[ "$backup_file" == *.gz ]]; then
        print_message "$YELLOW" "Detected gzipped backup, decompressing..."

        # Restore from pg_dumpall format
        gunzip -c "$backup_file" | PGPASSWORD="$POSTGRES_PASSWORD" psql \
            -h "$POSTGRES_HOST" \
            -p "$POSTGRES_PORT" \
            -U "$POSTGRES_USER" \
            postgres
    else
        # Restore from pg_dump custom format
        PGPASSWORD="$POSTGRES_PASSWORD" pg_restore \
            -h "$POSTGRES_HOST" \
            -p "$POSTGRES_PORT" \
            -U "$POSTGRES_USER" \
            -d "$POSTGRES_DB" \
            --clean \
            --if-exists \
            --verbose \
            "$backup_file"
    fi

    if [ $? -eq 0 ]; then
        print_message "$GREEN" "Restore completed successfully!"
    else
        print_message "$RED" "ERROR: Restore failed!"
        exit 1
    fi
}

# Function to call backup-manager for S3 operations
call_backup_manager() {
    local script=$1
    shift
    local args="$@"

    # Check if backup-manager container is available
    if command -v docker &> /dev/null; then
        # Running from host, use docker exec
        if docker ps | grep -q "postgres-backup-manager"; then
            docker exec postgres-backup-manager "$script" $args
            return $?
        else
            print_message "$RED" "ERROR: backup-manager container not running"
            return 1
        fi
    else
        # Running inside container, call script directly
        if [ -x "$script" ]; then
            "$script" $args
            return $?
        else
            print_message "$RED" "ERROR: Script not available: $script"
            return 1
        fi
    fi
}

# Function to list S3 backups
list_s3_backups() {
    print_message "$YELLOW" "=== Listing S3 Backups ==="
    call_backup_manager "/s3-scripts/download-from-s3.sh" "--list" "${1:-all}"
}

# Function to restore from S3
restore_from_s3() {
    local backup_type=$1
    local specific_file=$2

    print_message "$YELLOW" "=== Restoring from S3 ==="

    local downloaded_file=""

    if [ -n "$specific_file" ]; then
        # Download specific file
        print_message "$YELLOW" "Downloading: $specific_file"
        downloaded_file=$(call_backup_manager "/s3-scripts/download-from-s3.sh" "--download" "$specific_file" | tail -1)
    else
        # Download latest backup of specified type
        print_message "$YELLOW" "Downloading latest $backup_type backup..."
        downloaded_file=$(call_backup_manager "/s3-scripts/download-from-s3.sh" "--download-latest" "$backup_type" | tail -1)
    fi

    if [ $? -ne 0 ] || [ -z "$downloaded_file" ]; then
        print_message "$RED" "ERROR: Failed to download backup from S3"
        exit 1
    fi

    # Verify downloaded file exists
    if [ ! -f "$downloaded_file" ]; then
        print_message "$RED" "ERROR: Downloaded file not found: $downloaded_file"
        exit 1
    fi

    print_message "$GREEN" "Download completed: $downloaded_file"
    echo ""

    # Perform restore
    perform_restore "$downloaded_file"

    # Cleanup downloaded file
    print_message "$YELLOW" "Cleaning up temporary files..."
    rm -f "$downloaded_file"
}

# Main script
if [ $# -eq 0 ]; then
    # No arguments, list available backups
    list_backups
    echo ""
    print_message "$YELLOW" "Usage: $0 <backup_file_path>"
    print_message "$YELLOW" "   or: $0 --list"
    print_message "$YELLOW" "   or: $0 --latest [daily|weekly|monthly]"
    print_message "$YELLOW" "   or: $0 --list-s3 [daily|weekly|monthly|all]"
    print_message "$YELLOW" "   or: $0 --from-s3 <daily|weekly|monthly> [--latest]"
    print_message "$YELLOW" "   or: $0 --from-s3-file <s3_path>"
    echo ""
    echo "Examples:"
    echo "  $0 /backups/daily/backup_mydb_20231015_020000.dump"
    echo "  $0 --latest daily"
    echo "  $0 --list-s3"
    echo "  $0 --from-s3 daily --latest"
    echo "  $0 --from-s3-file s3://bucket/postgres-backups/daily/backup_xxx.dump"
    exit 0
fi

# Parse arguments
case "$1" in
    --list)
        list_backups
        ;;
    --latest)
        BACKUP_TYPE=${2:-daily}
        LATEST_BACKUP=$(ls -t "${BACKUP_DIR}/${BACKUP_TYPE}"/backup_* 2>/dev/null | head -1)

        if [ -z "$LATEST_BACKUP" ]; then
            print_message "$RED" "ERROR: No backups found in ${BACKUP_TYPE}"
            exit 1
        fi

        print_message "$GREEN" "Latest $BACKUP_TYPE backup: $LATEST_BACKUP"
        perform_restore "$LATEST_BACKUP"
        ;;
    --list-s3)
        list_s3_backups "${2:-all}"
        ;;
    --from-s3)
        if [ -z "$2" ]; then
            print_message "$RED" "ERROR: Backup type required (daily, weekly, monthly)"
            exit 1
        fi
        restore_from_s3 "$2"
        ;;
    --from-s3-file)
        if [ -z "$2" ]; then
            print_message "$RED" "ERROR: S3 file path required"
            exit 1
        fi
        restore_from_s3 "" "$2"
        ;;
    *)
        # Direct backup file path
        perform_restore "$1"
        ;;
esac

exit 0
