#!/bin/bash

###############################################################################
# PostgreSQL Backup Setup Script
# Description: Complete setup for PostgreSQL backup with S3 integration
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  PostgreSQL 18 Backup System Setup with S3            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check if .env exists
echo -e "${YELLOW}Step 1: Checking environment configuration...${NC}"
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠ .env file not found. Creating from template...${NC}"
    cp .env.example .env
    echo -e "${RED}⚠ Please edit .env file with your credentials:${NC}"
    echo -e "  - AWS_ACCESS_KEY_ID"
    echo -e "  - AWS_SECRET_ACCESS_KEY"
    echo -e "  - S3_BUCKET_NAME"
    echo -e "  - POSTGRES_PASSWORD"
    echo ""
    read -p "Press Enter after editing .env file..."
else
    echo -e "${GREEN}✓ .env file found${NC}"
fi

# Step 2: Build containers
echo ""
echo -e "${YELLOW}Step 2: Building Docker containers...${NC}"
docker-compose build
echo -e "${GREEN}✓ Containers built successfully${NC}"

# Step 3: Start services
echo ""
echo -e "${YELLOW}Step 3: Starting services...${NC}"
docker-compose up -d
echo -e "${GREEN}✓ Services started${NC}"

# Step 4: Wait for PostgreSQL
echo ""
echo -e "${YELLOW}Step 4: Waiting for PostgreSQL to be ready...${NC}"
sleep 5
for i in {1..30}; do
    if docker exec postgres-18 pg_isready -U postgres >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
        break
    fi
    echo -n "."
    sleep 1
done

# Step 5: Test S3 connectivity
echo ""
echo -e "${YELLOW}Step 5: Testing AWS S3 connectivity...${NC}"
if docker exec postgres-backup-manager aws s3 ls s3://$(grep S3_BUCKET_NAME .env | cut -d '=' -f2) >/dev/null 2>&1; then
    echo -e "${GREEN}✓ S3 connection successful${NC}"
else
    echo -e "${RED}✗ S3 connection failed. Please check AWS credentials in .env${NC}"
    exit 1
fi

# Step 6: Run test backup
echo ""
echo -e "${YELLOW}Step 6: Running test backup...${NC}"
docker exec postgres-18 /backup-scripts/backup.sh
echo -e "${GREEN}✓ Test backup completed${NC}"

# Step 7: Verify backup
echo ""
echo -e "${YELLOW}Step 7: Verifying backup...${NC}"

# Check local backup
LOCAL_BACKUP=$(docker exec postgres-18 ls -t /backups/daily/ 2>/dev/null | head -1)
if [ -n "$LOCAL_BACKUP" ]; then
    echo -e "${GREEN}✓ Local backup created: $LOCAL_BACKUP${NC}"
else
    echo -e "${RED}✗ Local backup not found${NC}"
fi

# Check S3 backup
S3_BUCKET=$(grep S3_BUCKET_NAME .env | cut -d '=' -f2)
S3_PREFIX=$(grep S3_BACKUP_PREFIX .env | cut -d '=' -f2)
S3_BACKUP=$(docker exec postgres-backup-manager aws s3 ls s3://${S3_BUCKET}/${S3_PREFIX}/daily/ 2>/dev/null | tail -1)
if [ -n "$S3_BACKUP" ]; then
    echo -e "${GREEN}✓ S3 backup uploaded successfully${NC}"
else
    echo -e "${YELLOW}⚠ S3 backup not found (check logs)${NC}"
fi

# Step 8: Setup Cron
echo ""
echo -e "${YELLOW}Step 8: Setup automated backup (cron)...${NC}"
echo -e "Choose cron schedule:"
echo -e "  ${GREEN}1${NC}) Daily at 2 AM (recommended)"
echo -e "  ${GREEN}2${NC}) Every 6 hours"
echo -e "  ${GREEN}3${NC}) Daily at 2 AM and 2 PM"
echo -e "  ${GREEN}4${NC}) Custom schedule"
echo -e "  ${GREEN}5${NC}) Skip cron setup (manual only)"
echo ""
read -p "Enter choice [1-5]: " CRON_CHOICE

CRON_SCHEDULE=""
case $CRON_CHOICE in
    1)
        CRON_SCHEDULE="0 2 * * *"
        CRON_DESC="Daily at 2 AM"
        ;;
    2)
        CRON_SCHEDULE="0 */6 * * *"
        CRON_DESC="Every 6 hours"
        ;;
    3)
        CRON_SCHEDULE="0 2,14 * * *"
        CRON_DESC="Daily at 2 AM and 2 PM"
        ;;
    4)
        echo "Enter cron schedule (e.g., '0 2 * * *'):"
        read -p "> " CRON_SCHEDULE
        CRON_DESC="Custom: $CRON_SCHEDULE"
        ;;
    5)
        echo -e "${YELLOW}⚠ Skipping cron setup${NC}"
        ;;
    *)
        echo -e "${RED}Invalid choice. Skipping cron setup${NC}"
        ;;
esac

if [ -n "$CRON_SCHEDULE" ]; then
    SCRIPT_DIR=$(pwd)
    CRON_CMD="$CRON_SCHEDULE cd $SCRIPT_DIR && docker exec postgres-18 /backup-scripts/backup.sh >> $SCRIPT_DIR/logs/cron.log 2>&1"

    # Check if cron already exists
    if crontab -l 2>/dev/null | grep -q "postgres-18.*backup.sh"; then
        echo -e "${YELLOW}⚠ Cron job already exists. Skipping...${NC}"
    else
        # Add to crontab
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
        echo -e "${GREEN}✓ Cron job added: $CRON_DESC${NC}"
    fi
fi

# Step 9: Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Setup Complete!                                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ PostgreSQL 18 with automated backup is ready${NC}"
echo ""
echo -e "${YELLOW}Quick Commands:${NC}"
echo -e "  ${BLUE}Manual backup:${NC}"
echo -e "    docker exec postgres-18 /backup-scripts/backup.sh"
echo ""
echo -e "  ${BLUE}List local backups:${NC}"
echo -e "    docker exec postgres-18 /backup-scripts/restore.sh --list"
echo ""
echo -e "  ${BLUE}List S3 backups:${NC}"
echo -e "    docker exec postgres-18 /backup-scripts/restore.sh --list-s3"
echo ""
echo -e "  ${BLUE}Restore from local:${NC}"
echo -e "    docker exec postgres-18 /backup-scripts/restore.sh --latest daily"
echo ""
echo -e "  ${BLUE}Restore from S3:${NC}"
echo -e "    docker exec postgres-18 /backup-scripts/restore.sh --from-s3 daily"
echo ""
echo -e "  ${BLUE}View logs:${NC}"
echo -e "    tail -f logs/backup_\$(date +%Y%m%d).log"
echo -e "    tail -f logs/s3_upload_\$(date +%Y%m%d).log"
echo -e "    tail -f logs/cron.log"
echo ""
echo -e "  ${BLUE}Check container status:${NC}"
echo -e "    docker ps"
echo -e "    docker logs postgres-18"
echo -e "    docker logs postgres-backup-manager"
echo ""

if [ -n "$CRON_SCHEDULE" ]; then
    echo -e "${GREEN}Automated backup scheduled: $CRON_DESC${NC}"
    echo -e "View cron jobs: ${BLUE}crontab -l${NC}"
fi

echo ""
echo -e "${YELLOW}Documentation:${NC}"
echo -e "  - Main README: README.md"
echo -e "  - S3 Integration: S3_INTEGRATION.md"
echo -e "  - Backup Manager: backup-manager/README.md"
echo ""
echo -e "${GREEN}Happy backing up! 🚀${NC}"
