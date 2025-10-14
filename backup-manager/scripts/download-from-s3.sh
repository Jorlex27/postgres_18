#!/bin/bash

###############################################################################
# S3 Download Script for PostgreSQL Backups
# Description: Download backup files from AWS S3 for restoration
###############################################################################

# Configuration from environment variables
S3_BUCKET_NAME="${S3_BUCKET_NAME:-}"
S3_BACKUP_PREFIX="${S3_BACKUP_PREFIX:-postgres-backups}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-ap-southeast-2}"
LOG_DIR="${LOG_DIR:-/logs}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/tmp/s3-downloads}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="${LOG_DIR}/s3_download_$(date +%Y%m%d).log"

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if AWS CLI is configured
check_aws_config() {
    if [ -z "$S3_BUCKET_NAME" ]; then
        log_message "ERROR" "S3_BUCKET_NAME is not set"
        print_message "$RED" "ERROR: S3_BUCKET_NAME environment variable is required"
        return 1
    fi

    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
        log_message "ERROR" "AWS credentials are not set"
        print_message "$RED" "ERROR: AWS credentials not configured"
        return 1
    fi

    # Test AWS connection
    if ! aws s3 ls "s3://${S3_BUCKET_NAME}" --region "${AWS_DEFAULT_REGION}" >/dev/null 2>&1; then
        log_message "ERROR" "Cannot access S3 bucket: ${S3_BUCKET_NAME}"
        print_message "$RED" "ERROR: Cannot access S3 bucket. Check credentials and bucket name."
        return 1
    fi

    return 0
}

# Function to list S3 backups
list_s3_backups() {
    local backup_type=${1:-all}

    print_message "$YELLOW" "=== Available S3 Backups ==="
    echo ""

    if [ "$backup_type" = "all" ] || [ "$backup_type" = "daily" ]; then
        print_message "$GREEN" "DAILY Backups:"
        aws s3 ls "s3://${S3_BUCKET_NAME}/${S3_BACKUP_PREFIX}/daily/" \
            --region "${AWS_DEFAULT_REGION}" \
            --recursive \
            --human-readable \
            --summarize 2>/dev/null | grep -v "^Total" | awk '{print "  " $4 " (" $3 ", " $1 " " $2 ")"}'
        echo ""
    fi

    if [ "$backup_type" = "all" ] || [ "$backup_type" = "weekly" ]; then
        print_message "$GREEN" "WEEKLY Backups:"
        aws s3 ls "s3://${S3_BUCKET_NAME}/${S3_BACKUP_PREFIX}/weekly/" \
            --region "${AWS_DEFAULT_REGION}" \
            --recursive \
            --human-readable \
            --summarize 2>/dev/null | grep -v "^Total" | awk '{print "  " $4 " (" $3 ", " $1 " " $2 ")"}'
        echo ""
    fi

    if [ "$backup_type" = "all" ] || [ "$backup_type" = "monthly" ]; then
        print_message "$GREEN" "MONTHLY Backups:"
        aws s3 ls "s3://${S3_BUCKET_NAME}/${S3_BACKUP_PREFIX}/monthly/" \
            --region "${AWS_DEFAULT_REGION}" \
            --recursive \
            --human-readable \
            --summarize 2>/dev/null | grep -v "^Total" | awk '{print "  " $4 " (" $3 ", " $1 " " $2 ")"}'
        echo ""
    fi
}

# Function to download file from S3
download_from_s3() {
    local s3_path=$1
    local local_file=$2

    # Create download directory if not exists
    mkdir -p "$(dirname "$local_file")"

    log_message "INFO" "=== Starting S3 Download ==="
    log_message "INFO" "S3 source: $s3_path"
    log_message "INFO" "Local destination: $local_file"

    print_message "$BLUE" "Downloading from S3..."

    if aws s3 cp "$s3_path" "$local_file" \
        --region "${AWS_DEFAULT_REGION}" \
        2>&1 | tee -a "$LOG_FILE"; then

        log_message "SUCCESS" "Download completed successfully"

        # Verify file exists and has content
        if [ -f "$local_file" ] && [ -s "$local_file" ]; then
            local file_size=$(du -h "$local_file" | cut -f1)
            print_message "$GREEN" "✓ Download successful: $local_file ($file_size)"
            log_message "INFO" "Downloaded file size: $file_size"
            echo "$local_file"
            return 0
        else
            log_message "ERROR" "Downloaded file is empty or missing"
            print_message "$RED" "✗ Download failed: file is empty"
            return 1
        fi
    else
        log_message "ERROR" "Download failed"
        print_message "$RED" "✗ Download failed"
        return 1
    fi
}

# Function to get latest backup from S3
get_latest_s3_backup() {
    local backup_type=$1
    local s3_prefix="s3://${S3_BUCKET_NAME}/${S3_BACKUP_PREFIX}/${backup_type}/"

    log_message "INFO" "Finding latest $backup_type backup in S3"

    # Get latest backup (sorted by date)
    local latest=$(aws s3 ls "$s3_prefix" \
        --region "${AWS_DEFAULT_REGION}" \
        --recursive | \
        sort -r | \
        head -1 | \
        awk '{print $4}')

    if [ -z "$latest" ]; then
        log_message "ERROR" "No $backup_type backups found in S3"
        print_message "$RED" "ERROR: No $backup_type backups found in S3"
        return 1
    fi

    echo "s3://${S3_BUCKET_NAME}/${latest}"
    return 0
}

# Function to download and prepare for restore
download_for_restore() {
    local s3_path=$1
    local filename=$(basename "$s3_path")
    local local_file="${DOWNLOAD_DIR}/${filename}"

    # Download file
    if download_from_s3 "$s3_path" "$local_file"; then
        echo "$local_file"
        return 0
    else
        return 1
    fi
}

# Function to cleanup downloaded files
cleanup_downloads() {
    local keep_latest=${1:-false}

    if [ "$keep_latest" = "false" ]; then
        log_message "INFO" "Cleaning up download directory: $DOWNLOAD_DIR"
        rm -rf "$DOWNLOAD_DIR"/*
        print_message "$YELLOW" "Cleaned up temporary download files"
    fi
}

# Main script
main() {
    print_message "$BLUE" "=== PostgreSQL Backup S3 Download Manager ==="

    # Check AWS configuration
    if ! check_aws_config; then
        exit 1
    fi

    # Create download directory
    mkdir -p "$DOWNLOAD_DIR"

    # Parse arguments
    if [ $# -eq 0 ]; then
        print_message "$YELLOW" "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  --list [daily|weekly|monthly|all]    List available backups in S3"
        echo "  --latest <daily|weekly|monthly>       Get latest backup path"
        echo "  --download <s3_path>                  Download specific backup"
        echo "  --download-latest <backup_type>       Download latest backup"
        echo "  --cleanup                             Clean up downloaded files"
        exit 1
    fi

    case "$1" in
        --list)
            list_s3_backups "${2:-all}"
            ;;
        --latest)
            if [ -z "$2" ]; then
                print_message "$RED" "ERROR: Backup type required (daily, weekly, monthly)"
                exit 1
            fi
            get_latest_s3_backup "$2"
            ;;
        --download)
            if [ -z "$2" ]; then
                print_message "$RED" "ERROR: S3 path required"
                exit 1
            fi
            local filename=$(basename "$2")
            download_for_restore "$2"
            ;;
        --download-latest)
            if [ -z "$2" ]; then
                print_message "$RED" "ERROR: Backup type required (daily, weekly, monthly)"
                exit 1
            fi
            local s3_path=$(get_latest_s3_backup "$2")
            if [ $? -eq 0 ]; then
                print_message "$BLUE" "Latest $2 backup: $s3_path"
                download_for_restore "$s3_path"
            else
                exit 1
            fi
            ;;
        --cleanup)
            cleanup_downloads false
            ;;
        *)
            print_message "$RED" "ERROR: Unknown command: $1"
            exit 1
            ;;
    esac

    exit $?
}

# Run main function
main "$@"
