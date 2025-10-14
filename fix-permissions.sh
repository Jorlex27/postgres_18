#!/bin/bash

###############################################################################
# Permission Fix Script for PostgreSQL Backup System
# Description: Fix ownership and permissions for backup directories
# Usage: sudo ./fix-permissions.sh [username]
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: Please run as root or with sudo${NC}"
    echo "Usage: sudo ./fix-permissions.sh [username]"
    exit 1
fi

# Get username from argument or current user
USERNAME=${1:-$SUDO_USER}

if [ -z "$USERNAME" ]; then
    echo -e "${RED}ERROR: Cannot determine username${NC}"
    echo "Usage: sudo ./fix-permissions.sh username"
    exit 1
fi

# Check if user exists
if ! id "$USERNAME" &>/dev/null; then
    echo -e "${RED}ERROR: User '$USERNAME' does not exist${NC}"
    exit 1
fi

# Get user's group
USERGROUP=$(id -gn "$USERNAME")

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  PostgreSQL Backup - Permission Fix                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}User: ${NC}$USERNAME"
echo -e "${YELLOW}Group: ${NC}$USERGROUP"
echo -e "${YELLOW}Working Directory: ${NC}$(pwd)"
echo ""

# Function to fix directory/file permissions
fix_permissions() {
    local path=$1
    local description=$2

    if [ -e "$path" ]; then
        echo -e "${YELLOW}Fixing: ${NC}$description"

        if [ -d "$path" ]; then
            # Directory
            chown -R $USERNAME:$USERGROUP "$path"
            chmod 755 "$path"
            echo -e "${GREEN}  ✓ ${NC}Directory ownership: $USERNAME:$USERGROUP"
            echo -e "${GREEN}  ✓ ${NC}Directory permission: 755"

            # Fix files inside
            if [ "$(ls -A $path 2>/dev/null)" ]; then
                chmod 644 "$path"/* 2>/dev/null || true
                echo -e "${GREEN}  ✓ ${NC}Files permission: 644"
            fi
        else
            # File
            chown $USERNAME:$USERGROUP "$path"
            chmod 644 "$path"
            echo -e "${GREEN}  ✓ ${NC}File ownership: $USERNAME:$USERGROUP"
            echo -e "${GREEN}  ✓ ${NC}File permission: 644"
        fi
    else
        echo -e "${YELLOW}Skipping: ${NC}$description (not found)"
    fi
    echo ""
}

# Function to fix script permissions (make executable)
fix_script_permissions() {
    local script=$1
    local description=$2

    if [ -f "$script" ]; then
        echo -e "${YELLOW}Fixing: ${NC}$description"
        chown $USERNAME:$USERGROUP "$script"
        chmod 755 "$script"
        echo -e "${GREEN}  ✓ ${NC}Script ownership: $USERNAME:$USERGROUP"
        echo -e "${GREEN}  ✓ ${NC}Script permission: 755 (executable)"
    else
        echo -e "${RED}  ✗ ${NC}Script not found: $script"
    fi
    echo ""
}

echo -e "${BLUE}=== Fixing Directory Permissions ===${NC}"
echo ""

# Fix backup directories
fix_permissions "backups" "Backups directory"
fix_permissions "backups/daily" "Daily backups"
fix_permissions "backups/weekly" "Weekly backups"
fix_permissions "backups/monthly" "Monthly backups"

# Fix logs directory
fix_permissions "logs" "Logs directory"

# Fix backup-scripts directory
fix_permissions "backup-scripts" "Backup scripts directory"

# Fix backup-manager directory
fix_permissions "backup-manager" "Backup manager directory"
fix_permissions "backup-manager/scripts" "Backup manager scripts"

echo -e "${BLUE}=== Fixing Script Permissions (Make Executable) ===${NC}"
echo ""

# Fix main scripts
fix_script_permissions "backup-with-s3.sh" "Main backup script"
fix_script_permissions "setup-backup.sh" "Setup wizard"

# Fix backup scripts
fix_script_permissions "backup-scripts/backup.sh" "Backup script"
fix_script_permissions "backup-scripts/restore.sh" "Restore script"
fix_script_permissions "backup-scripts/setup-cron.sh" "Cron setup script"

# Fix backup-manager scripts
fix_script_permissions "backup-manager/scripts/upload-to-s3.sh" "S3 upload script"
fix_script_permissions "backup-manager/scripts/download-from-s3.sh" "S3 download script"
fix_script_permissions "backup-manager/scripts/s3-helper.sh" "S3 helper script"

echo -e "${BLUE}=== Verifying Permissions ===${NC}"
echo ""

# Show current permissions
echo -e "${YELLOW}Current permissions:${NC}"
ls -lhd backups logs backup-scripts backup-manager 2>/dev/null || true
echo ""
ls -lh *.sh 2>/dev/null || true
echo ""

echo -e "${BLUE}=== Permission Fix Summary ===${NC}"
echo ""
echo -e "${GREEN}✓ All directories and files owned by: ${NC}$USERNAME:$USERGROUP"
echo -e "${GREEN}✓ Directories: ${NC}755 (rwxr-xr-x)"
echo -e "${GREEN}✓ Regular files: ${NC}644 (rw-r--r--)"
echo -e "${GREEN}✓ Scripts: ${NC}755 (rwxr-xr-x) - executable"
echo ""
echo -e "${GREEN}=== Permission Fix Completed Successfully! ===${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test backup script:"
echo -e "   ${BLUE}./backup-with-s3.sh${NC}"
echo ""
echo "2. Setup cron job:"
echo -e "   ${BLUE}crontab -e${NC}"
echo ""
echo "3. Verify cron can write to logs:"
echo -e "   ${BLUE}touch logs/test.log && rm logs/test.log${NC}"
echo ""
