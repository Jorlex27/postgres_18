#!/bin/bash

###############################################################################
# S3 Upload Script for PostgreSQL Backups
# Description: Upload backup files to AWS S3 with retry logic and encryption
###############################################################################

# Configuration from environment variables
S3_BUCKET_NAME="${S3_BUCKET_NAME:-}"
S3_BACKUP_PREFIX="${S3_BACKUP_PREFIX:-postgres-backups}"
S3_STORAGE_CLASS="${S3_STORAGE_CLASS:-STANDARD_IA}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-ap-southeast-2}"
LOG_DIR="${LOG_DIR:-/logs}"

# Retry configuration
MAX_RETRIES=3
RETRY_DELAY=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="${LOG_DIR}/s3_upload_$(date +%Y%m%d).log"

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

# Function to upload file to S3 with retry
upload_with_retry() {
    local local_file=$1
    local s3_path=$2
    local attempt=1

    while [ $attempt -le $MAX_RETRIES ]; do
        log_message "INFO" "Upload attempt $attempt/$MAX_RETRIES: $local_file -> $s3_path"

        if aws s3 cp "$local_file" "$s3_path" \
            --region "${AWS_DEFAULT_REGION}" \
            --storage-class "${S3_STORAGE_CLASS}" \
            --sse AES256 \
            2>&1 | tee -a "$LOG_FILE"; then

            log_message "SUCCESS" "Upload completed: $s3_path"
            return 0
        else
            log_message "WARNING" "Upload attempt $attempt failed"

            if [ $attempt -lt $MAX_RETRIES ]; then
                local wait_time=$((RETRY_DELAY * attempt))
                log_message "INFO" "Retrying in ${wait_time} seconds..."
                sleep $wait_time
            fi
        fi

        attempt=$((attempt + 1))
    done

    log_message "ERROR" "Upload failed after $MAX_RETRIES attempts"
    return 1
}

# Function to verify upload
verify_upload() {
    local s3_path=$1

    log_message "INFO" "Verifying upload: $s3_path"

    if aws s3 ls "$s3_path" --region "${AWS_DEFAULT_REGION}" >/dev/null 2>&1; then
        log_message "SUCCESS" "Upload verified successfully"
        return 0
    else
        log_message "ERROR" "Upload verification failed"
        return 1
    fi
}

# Function to get file size in human readable format
get_file_size() {
    local file=$1
    if [ -f "$file" ]; then
        du -h "$file" | cut -f1
    else
        echo "N/A"
    fi
}

# Main upload function
upload_backup() {
    local backup_file=$1

    # Validate backup file exists
    if [ ! -f "$backup_file" ]; then
        log_message "ERROR" "Backup file not found: $backup_file"
        print_message "$RED" "ERROR: Backup file not found: $backup_file"
        return 1
    fi

    # Extract backup type and filename
    local backup_type=""
    if [[ "$backup_file" == *"/daily/"* ]]; then
        backup_type="daily"
    elif [[ "$backup_file" == *"/weekly/"* ]]; then
        backup_type="weekly"
    elif [[ "$backup_file" == *"/monthly/"* ]]; then
        backup_type="monthly"
    else
        log_message "ERROR" "Cannot determine backup type from path: $backup_file"
        print_message "$RED" "ERROR: Cannot determine backup type"
        return 1
    fi

    local filename=$(basename "$backup_file")
    local file_size=$(get_file_size "$backup_file")

    # Construct S3 path
    local s3_path="s3://${S3_BUCKET_NAME}/${S3_BACKUP_PREFIX}/${backup_type}/${filename}"

    log_message "INFO" "=== Starting S3 Upload ==="
    log_message "INFO" "Local file: $backup_file"
    log_message "INFO" "File size: $file_size"
    log_message "INFO" "Backup type: $backup_type"
    log_message "INFO" "S3 destination: $s3_path"
    log_message "INFO" "Storage class: $S3_STORAGE_CLASS"
    log_message "INFO" "Encryption: SSE-S3 (AES256)"

    print_message "$BLUE" "Uploading $filename ($file_size) to S3..."

    # Perform upload with retry
    if upload_with_retry "$backup_file" "$s3_path"; then
        # Verify upload
        if verify_upload "$s3_path"; then
            print_message "$GREEN" "✓ Upload successful: $s3_path"
            log_message "SUCCESS" "Backup uploaded and verified successfully"

            # Get S3 object info
            local s3_size=$(aws s3 ls "$s3_path" --region "${AWS_DEFAULT_REGION}" | awk '{print $3}')
            log_message "INFO" "S3 object size: $s3_size bytes"

            return 0
        else
            print_message "$RED" "✗ Upload verification failed"
            return 1
        fi
    else
        print_message "$RED" "✗ Upload failed after $MAX_RETRIES attempts"
        return 1
    fi
}

# Main script
main() {
    print_message "$BLUE" "=== PostgreSQL Backup S3 Upload Manager ==="

    # Check AWS configuration
    if ! check_aws_config; then
        exit 1
    fi

    # Parse arguments
    if [ $# -eq 0 ]; then
        print_message "$YELLOW" "Usage: $0 <backup_file_path>"
        print_message "$YELLOW" "   or: $0 --upload-latest <daily|weekly|monthly>"
        exit 1
    fi

    case "$1" in
        --upload-latest)
            local backup_type=${2:-daily}
            local backup_dir="/backups/${backup_type}"

            if [ ! -d "$backup_dir" ]; then
                log_message "ERROR" "Backup directory not found: $backup_dir"
                print_message "$RED" "ERROR: Backup directory not found"
                exit 1
            fi

            # Find latest backup
            local latest_backup=$(ls -t "$backup_dir"/backup_* 2>/dev/null | head -1)

            if [ -z "$latest_backup" ]; then
                log_message "ERROR" "No backups found in $backup_dir"
                print_message "$RED" "ERROR: No backups found"
                exit 1
            fi

            upload_backup "$latest_backup"
            ;;
        *)
            upload_backup "$1"
            ;;
    esac

    exit $?
}

# Run main function
main "$@"
