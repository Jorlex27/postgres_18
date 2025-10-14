# PostgreSQL 18 with S3 Backup - Complete Installation Guide

Panduan lengkap instalasi PostgreSQL 18 dengan automated backup ke AWS S3 dari awal sampai selesai.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step-by-Step Installation](#step-by-step-installation)
- [Testing & Verification](#testing--verification)
- [Setup Automated Backup](#setup-automated-backup)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Sebelum mulai, pastikan Anda sudah memiliki:

### 1. Software Requirements

- ✅ **Docker** installed dan running
- ✅ **Docker Compose** v2.0+
- ✅ **Git** (optional, untuk clone repository)
- ✅ **Text editor** (nano, vim, atau VS Code)

Check versi:
```bash
docker --version
docker-compose --version
```

### 2. AWS S3 Requirements

- ✅ **AWS Account** aktif
- ✅ **S3 Bucket** sudah dibuat (contoh: `db-backup-henotic`)
- ✅ **IAM User** dengan S3 access
- ✅ **Access Key** dan **Secret Key**

### 3. Sistem Requirements

- **RAM**: Minimal 2GB
- **Disk**: Minimal 10GB free space
- **OS**: Linux, macOS, atau Windows (dengan WSL2)

---

## Step-by-Step Installation

### Step 1: Clone atau Download Project

#### Option A: Clone dari Git
```bash
git clone <your-repo-url>
cd postgres-18
```

#### Option B: Manual Setup
```bash
# Create project directory
mkdir -p ~/postgres-18
cd ~/postgres-18

# Download files atau copy files yang sudah ada
```

### Step 2: Configure Environment Variables

1. **Copy template .env file**:
```bash
cp .env.example .env
```

2. **Edit .env file**:
```bash
nano .env
# or
vim .env
# or
code .env
```

3. **Fill in your credentials**:
```bash
# PostgreSQL Configuration
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_strong_password_here  # ⚠️ CHANGE THIS!
POSTGRES_DB=postgres
POSTGRES_PORT=5432

# pgAdmin Configuration (optional)
PGADMIN_EMAIL=admin@example.com
PGADMIN_PASSWORD=admin_password
PGADMIN_PORT=5050

# Backup Configuration
POSTGRES_HOST=localhost
BACKUP_DIR=/backups
LOG_DIR=/logs

# AWS S3 Configuration (⚠️ REQUIRED for S3 backup)
AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX           # ⚠️ Your AWS Access Key
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxx   # ⚠️ Your AWS Secret Key
AWS_DEFAULT_REGION=ap-southeast-2                # Your S3 region

# S3 Bucket Configuration
S3_BUCKET_NAME=db-backup-henotic                 # ⚠️ Your bucket name
S3_BACKUP_PREFIX=postgres-backups                # Folder prefix in S3
S3_STORAGE_CLASS=STANDARD_IA                     # Storage class
S3_UPLOAD_ENABLED=true                           # Enable S3 upload
```

**Important Notes:**
- ⚠️ **Never commit .env file to Git** (already in .gitignore)
- ⚠️ Use **strong passwords** for production
- ⚠️ AWS credentials must have S3 access permissions

### Step 3: Verify File Structure

Check bahwa semua file dan folder ada:

```bash
tree -L 2 -I '.git|node_modules'
```

Expected structure:
```
postgres-18/
├── docker-compose.yml
├── .env                          # ← Your configuration
├── .env.example
├── .gitignore
├── backup-with-s3.sh            # ← Auto backup + S3 upload
├── setup-backup.sh              # ← Interactive setup
├── README.md
├── S3_INTEGRATION.md
├── INSTALLATION_GUIDE.md        # ← This file
├── backup-scripts/
│   ├── backup.sh
│   ├── restore.sh
│   └── setup-cron.sh
├── backup-manager/
│   ├── Dockerfile
│   ├── README.md
│   └── scripts/
│       ├── upload-to-s3.sh
│       ├── download-from-s3.sh
│       └── s3-helper.sh
├── backups/                     # ← Will store local backups
│   ├── daily/
│   ├── weekly/
│   └── monthly/
├── logs/                        # ← Will store logs
└── init-scripts/                # ← PostgreSQL init scripts
```

### Step 4: Build Docker Containers

Build custom backup-manager container dengan AWS CLI:

```bash
docker-compose build
```

**Expected output:**
```
[+] Building 65.6s (13/13) FINISHED
 => [internal] load build definition from Dockerfile
 => => transferring dockerfile: 838B
 => [internal] load .dockerignore
 ...
 => exporting to image
 => => exporting layers
 => => writing image sha256:...
 backup-manager  Built
```

**Build time**: ~1-2 minutes (depending on internet speed)

### Step 5: Start Services

Start PostgreSQL dan backup-manager containers:

```bash
docker-compose up -d
```

**Expected output:**
```
[+] Running 5/5
 ✔ Network postgres-18_postgres_18_network  Created
 ✔ Volume postgres-18_postgres_18_data      Created
 ✔ Container postgres-18                    Started
 ✔ Container postgres-backup-manager        Started
```

### Step 6: Wait for PostgreSQL Ready

Wait ~5-10 seconds for PostgreSQL to initialize:

```bash
sleep 5
docker exec postgres-18 pg_isready -U postgres
```

**Expected output:**
```
/var/run/postgresql:5432 - accepting connections
```

### Step 7: Verify Containers Running

Check container status:

```bash
docker ps
```

**Expected output:**
```
CONTAINER ID   IMAGE                    STATUS                    PORTS
xxxxxxxxxx     postgres:18-alpine       Up X seconds (healthy)    0.0.0.0:5432->5432/tcp
yyyyyyyyyy     backup-manager          Up X seconds (healthy)
```

Both containers must show **(healthy)** status.

### Step 8: Test S3 Connectivity

Verify AWS S3 connection:

```bash
docker exec postgres-backup-manager aws s3 ls s3://db-backup-henotic
```

**If successful**: No error (empty output is OK if bucket is empty)

**If failed**:
```
An error occurred (AccessDenied) when calling the ListObjectsV2 operation
```
→ Check AWS credentials in `.env` file

### Step 9: Run First Backup Test

Test complete backup flow (local + S3):

```bash
./backup-with-s3.sh
```

**Expected output:**
```
[2025-10-14 12:49:24] === Starting PostgreSQL Backup with S3 Upload ===
[2025-10-14 12:49:24] Both containers are running ✓
[2025-10-14 12:49:24] Step 1: Creating PostgreSQL backup...
[2025-10-14 12:49:24] SUCCESS: Local backup completed
[2025-10-14 12:49:24] Step 2: Finding latest backup file...
[2025-10-14 12:49:24] Latest backup: /backups/daily/backup_postgres_YYYYMMDD_HHMMSS.dump
[2025-10-14 12:49:24] Step 3: Uploading to S3...
[2025-10-14 12:49:28] SUCCESS: S3 upload completed
[2025-10-14 12:49:28] Step 4: Verifying S3 upload...
[2025-10-14 12:49:29] SUCCESS: S3 backup verified
[2025-10-14 12:49:29] === Backup Process Completed Successfully ===
```

### Step 10: Verify Backups Created

**Check local backup:**
```bash
docker exec postgres-18 ls -lh /backups/daily/
```

Expected:
```
total 4K
-rw-r--r-- 1 root root 1.0K Oct 14 05:49 backup_postgres_20251014_054924.dump
```

**Check S3 backup:**
```bash
docker exec postgres-backup-manager aws s3 ls s3://db-backup-henotic/postgres-backups/daily/ --human-readable
```

Expected:
```
2025-10-14 16:49:27  1.0 KiB backup_postgres_20251014_054924.dump
```

---

## Testing & Verification

### Test 1: List Available Backups

**Local backups:**
```bash
docker exec postgres-18 /backup-scripts/restore.sh --list
```

**S3 backups:**
```bash
docker exec postgres-backup-manager aws s3 ls s3://db-backup-henotic/postgres-backups/ --recursive --human-readable
```

### Test 2: Test Database Connection

```bash
docker exec -it postgres-18 psql -U postgres -d postgres
```

Inside psql:
```sql
-- Check PostgreSQL version
SELECT version();

-- List databases
\l

-- Exit
\q
```

### Test 3: Test Restore (Optional)

⚠️ **Warning**: This will overwrite your database!

```bash
# Restore from latest local backup
docker exec -it postgres-18 /backup-scripts/restore.sh --latest daily
```

### Test 4: Check Logs

**Backup log:**
```bash
cat logs/backup_$(date +%Y%m%d).log
```

**S3 upload log:**
```bash
cat logs/s3_upload_$(date +%Y%m%d).log
```

**Wrapper log:**
```bash
cat logs/backup-wrapper_$(date +%Y%m%d).log
```

---

## Setup Automated Backup

### Option 1: Using Cron (Recommended)

#### 1. Edit crontab
```bash
crontab -e
```

#### 2. Add backup schedule

**Daily backup at 2 AM:**
```bash
0 2 * * * cd /path/to/postgres-18 && ./backup-with-s3.sh >> logs/cron.log 2>&1
```

**Important**: Replace `/path/to/postgres-18` with your actual project path!

Get current path:
```bash
pwd
```

**Other schedule examples:**

```bash
# Every 6 hours
0 */6 * * * cd /path/to/postgres-18 && ./backup-with-s3.sh >> logs/cron.log 2>&1

# Daily at 2 AM and 2 PM
0 2,14 * * * cd /path/to/postgres-18 && ./backup-with-s3.sh >> logs/cron.log 2>&1

# Every Sunday at 3 AM
0 3 * * 0 cd /path/to/postgres-18 && ./backup-with-s3.sh >> logs/cron.log 2>&1

# Every 1st of month at 4 AM
0 4 1 * * cd /path/to/postgres-18 && ./backup-with-s3.sh >> logs/cron.log 2>&1
```

#### 3. Verify cron job
```bash
crontab -l
```

#### 4. Test cron (change time to now + 2 minutes)

Example: If now is 14:30, set to:
```bash
32 14 * * * cd /path/to/postgres-18 && ./backup-with-s3.sh >> logs/cron.log 2>&1
```

Wait 2 minutes, then check:
```bash
tail -f logs/cron.log
```

**Remember to change back to your actual schedule after testing!**

### Option 2: Using Interactive Setup Script

Run automated setup:
```bash
./setup-backup.sh
```

This script will guide you through:
1. Environment validation
2. Container setup
3. S3 connectivity test
4. Test backup execution
5. Cron job configuration (interactive)

---

## Post-Installation Checklist

After installation, verify:

- [ ] ✅ Containers running: `docker ps`
- [ ] ✅ PostgreSQL healthy: `docker exec postgres-18 pg_isready`
- [ ] ✅ S3 connection works: `docker exec postgres-backup-manager aws s3 ls s3://your-bucket`
- [ ] ✅ Local backup exists: `ls -lh backups/daily/`
- [ ] ✅ S3 backup exists: Check via AWS console or CLI
- [ ] ✅ Cron job configured: `crontab -l`
- [ ] ✅ Logs accessible: `ls -lh logs/`

---

## Troubleshooting

### Issue 1: Container Won't Start

**Symptoms:**
```
Error: Container exited with code 1
```

**Solutions:**
```bash
# Check logs
docker logs postgres-18
docker logs postgres-backup-manager

# Check .env file
cat .env

# Rebuild containers
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Issue 2: S3 Upload Failed

**Symptoms:**
```
ERROR: S3 upload failed
```

**Solutions:**

1. **Check AWS credentials:**
```bash
docker exec postgres-backup-manager env | grep AWS
```

2. **Test S3 access:**
```bash
docker exec postgres-backup-manager aws s3 ls
```

3. **Verify IAM permissions:**
- Go to AWS Console → IAM → Users → [your-user] → Permissions
- Ensure policy includes: `s3:PutObject`, `s3:GetObject`, `s3:ListBucket`

4. **Check bucket name:**
```bash
grep S3_BUCKET_NAME .env
```

### Issue 3: PostgreSQL Connection Refused

**Symptoms:**
```
psql: could not connect to server: Connection refused
```

**Solutions:**
```bash
# Wait for PostgreSQL to start
sleep 10
docker exec postgres-18 pg_isready

# Check if port is in use
lsof -i :5432

# Check PostgreSQL logs
docker logs postgres-18

# Restart container
docker-compose restart postgres
```

### Issue 4: Backup Script Not Executable

**Symptoms:**
```
bash: ./backup-with-s3.sh: Permission denied
```

**Solution:**
```bash
chmod +x backup-with-s3.sh
chmod +x setup-backup.sh
chmod +x backup-scripts/*.sh
```

### Issue 5: Disk Space Full

**Symptoms:**
```
ERROR: No space left on device
```

**Solutions:**
```bash
# Check disk space
df -h

# Remove old Docker images
docker system prune -a

# Remove old backups manually
docker exec postgres-18 rm -f /backups/daily/backup_old*.dump

# Adjust retention policy in backup.sh
```

### Issue 6: Cron Job Not Running

**Symptoms:**
- No new backups created
- cron.log is empty

**Solutions:**

1. **Check cron is running:**
```bash
ps aux | grep cron
```

2. **Check crontab syntax:**
```bash
crontab -l
```

3. **Use absolute paths:**
```bash
# ❌ Wrong (relative path)
0 2 * * * ./backup-with-s3.sh

# ✅ Correct (absolute path)
0 2 * * * /Users/alexveros/Documents/docker-files/postgres-18/backup-with-s3.sh
```

4. **Test manually:**
```bash
./backup-with-s3.sh
```

5. **Check cron logs:**
```bash
# macOS
tail -f /var/log/system.log | grep cron

# Linux
tail -f /var/log/syslog | grep CRON
```

---

## Quick Reference Commands

### Container Management
```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart services
docker-compose restart

# View logs
docker-compose logs -f

# Check status
docker ps
```

### Backup Operations
```bash
# Manual backup with S3 upload
./backup-with-s3.sh

# Manual backup only (no S3)
docker exec postgres-18 /backup-scripts/backup.sh

# Manual S3 upload
docker exec postgres-backup-manager /s3-scripts/upload-to-s3.sh /backups/daily/backup_xxx.dump

# List local backups
docker exec postgres-18 /backup-scripts/restore.sh --list

# List S3 backups
docker exec postgres-backup-manager aws s3 ls s3://db-backup-henotic/postgres-backups/ --recursive --human-readable
```

### Restore Operations
```bash
# Restore from latest local backup
docker exec -it postgres-18 /backup-scripts/restore.sh --latest daily

# Restore from specific file (local)
docker exec -it postgres-18 /backup-scripts/restore.sh /backups/daily/backup_xxx.dump

# Download and restore from S3
# (coming soon - use manual download for now)
```

### Monitoring
```bash
# View today's backup log
tail -f logs/backup_$(date +%Y%m%d).log

# View S3 upload log
tail -f logs/s3_upload_$(date +%Y%m%d).log

# View wrapper log
tail -f logs/backup-wrapper_$(date +%Y%m%d).log

# View cron log
tail -f logs/cron.log

# Check PostgreSQL health
docker exec postgres-18 pg_isready

# Check container health
docker inspect postgres-18 | grep -A 10 Health
```

---

## Next Steps

After successful installation:

1. **Test restore procedure** monthly
2. **Monitor backup logs** weekly
3. **Review S3 costs** monthly
4. **Update retention policies** as needed
5. **Document recovery procedures** for your team
6. **Setup monitoring alerts** (optional)

---

## Additional Resources

- [Main README](README.md) - User guide
- [S3 Integration Guide](S3_INTEGRATION.md) - Technical details
- [Backup Manager README](backup-manager/README.md) - S3 operations
- [PostgreSQL 18 Documentation](https://www.postgresql.org/docs/18/)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [Docker Documentation](https://docs.docker.com/)

---

## Support

For issues or questions:

1. Check [Troubleshooting](#troubleshooting) section
2. Review log files in `logs/` directory
3. Check container status: `docker ps`
4. Review documentation files

---

**Installation Guide Version**: 1.0
**Last Updated**: October 2025
**Status**: ✅ Production Ready
