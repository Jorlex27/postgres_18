#!/bin/bash

###############################################################################
# S3 Helper Functions
# Description: Common functions for S3 operations
###############################################################################

# Configuration from environment variables
S3_BUCKET_NAME="${S3_BUCKET_NAME:-}"
S3_BACKUP_PREFIX="${S3_BACKUP_PREFIX:-postgres-backups}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-ap-southeast-2}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check S3 connectivity
check_s3_connectivity() {
    if aws s3 ls "s3://${S3_BUCKET_NAME}" --region "${AWS_DEFAULT_REGION}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to get S3 bucket info
get_s3_bucket_info() {
    echo -e "${BLUE}=== S3 Bucket Information ===${NC}"
    echo "Bucket: ${S3_BUCKET_NAME}"
    echo "Region: ${AWS_DEFAULT_REGION}"
    echo "Prefix: ${S3_BACKUP_PREFIX}"
    echo ""

    # Get bucket size and object count
    aws s3 ls "s3://${S3_BUCKET_NAME}/${S3_BACKUP_PREFIX}/" \
        --region "${AWS_DEFAULT_REGION}" \
        --recursive \
        --human-readable \
        --summarize 2>/dev/null | tail -2
}

# Function to test S3 upload
test_s3_upload() {
    local test_file="/tmp/s3-test-$(date +%s).txt"
    local test_key="${S3_BACKUP_PREFIX}/test/test-file.txt"

    echo "Testing S3 upload..." > "$test_file"

    if aws s3 cp "$test_file" "s3://${S3_BUCKET_NAME}/${test_key}" \
        --region "${AWS_DEFAULT_REGION}" \
        --server-side-encryption AES256 >/dev/null 2>&1; then

        # Cleanup test file
        aws s3 rm "s3://${S3_BUCKET_NAME}/${test_key}" --region "${AWS_DEFAULT_REGION}" >/dev/null 2>&1
        rm -f "$test_file"
        echo -e "${GREEN}✓ S3 upload test successful${NC}"
        return 0
    else
        rm -f "$test_file"
        echo -e "${RED}✗ S3 upload test failed${NC}"
        return 1
    fi
}

# Function to calculate total S3 storage used
get_s3_storage_usage() {
    local backup_type=${1:-all}
    local total_size=0

    if [ "$backup_type" = "all" ]; then
        aws s3 ls "s3://${S3_BUCKET_NAME}/${S3_BACKUP_PREFIX}/" \
            --region "${AWS_DEFAULT_REGION}" \
            --recursive \
            --summarize 2>/dev/null | grep "Total Size" | awk '{print $3, $4}'
    else
        aws s3 ls "s3://${S3_BUCKET_NAME}/${S3_BACKUP_PREFIX}/${backup_type}/" \
            --region "${AWS_DEFAULT_REGION}" \
            --recursive \
            --summarize 2>/dev/null | grep "Total Size" | awk '{print $3, $4}'
    fi
}

# Export functions
export -f check_s3_connectivity
export -f get_s3_bucket_info
export -f test_s3_upload
export -f get_s3_storage_usage
