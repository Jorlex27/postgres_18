#!/bin/bash

###############################################################################
# Cron Job Setup Script for PostgreSQL Backup
# Author: Auto-generated
# Description: Sets up automated backup cron job
###############################################################################

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

# Get absolute path of backup script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKUP_SCRIPT="${SCRIPT_DIR}/backup.sh"

if [ ! -f "$BACKUP_SCRIPT" ]; then
    print_message "$RED" "ERROR: backup.sh not found at $BACKUP_SCRIPT"
    exit 1
fi

print_message "$YELLOW" "=== PostgreSQL Backup Cron Job Setup ==="
echo ""

# Default values
DEFAULT_HOUR="2"
DEFAULT_MINUTE="0"

# Ask for schedule
print_message "$GREEN" "Enter backup schedule:"
read -p "Hour (0-23) [default: $DEFAULT_HOUR]: " CRON_HOUR
read -p "Minute (0-59) [default: $DEFAULT_MINUTE]: " CRON_MINUTE

CRON_HOUR=${CRON_HOUR:-$DEFAULT_HOUR}
CRON_MINUTE=${CRON_MINUTE:-$DEFAULT_MINUTE}

# Validate input
if ! [[ "$CRON_HOUR" =~ ^[0-9]+$ ]] || [ "$CRON_HOUR" -lt 0 ] || [ "$CRON_HOUR" -gt 23 ]; then
    print_message "$RED" "ERROR: Invalid hour. Must be between 0-23"
    exit 1
fi

if ! [[ "$CRON_MINUTE" =~ ^[0-9]+$ ]] || [ "$CRON_MINUTE" -lt 0 ] || [ "$CRON_MINUTE" -gt 59 ]; then
    print_message "$RED" "ERROR: Invalid minute. Must be between 0-59"
    exit 1
fi

echo ""
print_message "$GREEN" "Enter PostgreSQL connection details:"
read -p "Host [default: localhost]: " PG_HOST
read -p "Port [default: 5432]: " PG_PORT
read -p "User [default: postgres]: " PG_USER
read -sp "Password: " PG_PASSWORD
echo ""
read -p "Database name [default: postgres, 'all' for all databases]: " PG_DB

PG_HOST=${PG_HOST:-localhost}
PG_PORT=${PG_PORT:-5432}
PG_USER=${PG_USER:-postgres}
PG_DB=${PG_DB:-postgres}

# Get absolute path for backup and log directories
read -p "Backup directory [default: ${SCRIPT_DIR}/../backups]: " BACKUP_DIR
read -p "Log directory [default: ${SCRIPT_DIR}/../logs]: " LOG_DIR

BACKUP_DIR=${BACKUP_DIR:-${SCRIPT_DIR}/../backups}
LOG_DIR=${LOG_DIR:-${SCRIPT_DIR}/../logs}

# Convert to absolute paths
BACKUP_DIR=$(cd "$BACKUP_DIR" 2>/dev/null && pwd || echo "$BACKUP_DIR")
LOG_DIR=$(cd "$LOG_DIR" 2>/dev/null && pwd || echo "$LOG_DIR")

echo ""
print_message "$YELLOW" "=== Configuration Summary ==="
echo "Schedule: Daily at $CRON_HOUR:$(printf "%02d" $CRON_MINUTE)"
echo "Host: $PG_HOST:$PG_PORT"
echo "User: $PG_USER"
echo "Database: $PG_DB"
echo "Backup Directory: $BACKUP_DIR"
echo "Log Directory: $LOG_DIR"
echo ""

read -p "Is this correct? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    print_message "$YELLOW" "Setup cancelled."
    exit 0
fi

# Create environment file for cron
ENV_FILE="${SCRIPT_DIR}/.backup.env"
cat > "$ENV_FILE" << EOF
# PostgreSQL Backup Environment Variables
# Generated on $(date)
export POSTGRES_HOST="$PG_HOST"
export POSTGRES_PORT="$PG_PORT"
export POSTGRES_USER="$PG_USER"
export POSTGRES_PASSWORD="$PG_PASSWORD"
export POSTGRES_DB="$PG_DB"
export BACKUP_DIR="$BACKUP_DIR"
export LOG_DIR="$LOG_DIR"
EOF

chmod 600 "$ENV_FILE"
print_message "$GREEN" "Environment file created: $ENV_FILE"

# Create cron job entry
CRON_JOB="$CRON_MINUTE $CRON_HOUR * * * . $ENV_FILE && $BACKUP_SCRIPT >> $LOG_DIR/cron.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -F "$BACKUP_SCRIPT" > /dev/null; then
    print_message "$YELLOW" "Existing cron job found. Removing old entry..."
    crontab -l 2>/dev/null | grep -v "$BACKUP_SCRIPT" | crontab -
fi

# Add new cron job
print_message "$YELLOW" "Adding cron job..."
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

if [ $? -eq 0 ]; then
    print_message "$GREEN" "Cron job added successfully!"
    echo ""
    print_message "$GREEN" "=== Current Crontab ==="
    crontab -l | grep "$BACKUP_SCRIPT"
    echo ""
    print_message "$YELLOW" "Backup will run daily at $CRON_HOUR:$(printf "%02d" $CRON_MINUTE)"
    print_message "$YELLOW" "Logs will be saved to: $LOG_DIR"
    echo ""
    print_message "$GREEN" "To view cron jobs: crontab -l"
    print_message "$GREEN" "To remove cron job: crontab -e (then delete the line)"
    print_message "$GREEN" "To test backup: $BACKUP_SCRIPT"
else
    print_message "$RED" "ERROR: Failed to add cron job"
    exit 1
fi

print_message "$GREEN" "Setup completed!"
