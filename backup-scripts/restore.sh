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

# Main script
if [ $# -eq 0 ]; then
    # No arguments, list available backups
    list_backups
    echo ""
    print_message "$YELLOW" "Usage: $0 <backup_file_path>"
    print_message "$YELLOW" "   or: $0 --list"
    print_message "$YELLOW" "   or: $0 --latest [daily|weekly|monthly]"
    echo ""
    echo "Examples:"
    echo "  $0 /backups/daily/backup_mydb_20231015_020000.dump"
    echo "  $0 --latest daily"
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
    *)
        # Direct backup file path
        perform_restore "$1"
        ;;
esac

exit 0
