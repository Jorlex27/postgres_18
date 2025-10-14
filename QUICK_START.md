# Quick Start Guide - PostgreSQL 18 with S3 Backup

Instalasi cepat dalam 5 menit untuk yang sudah familiar dengan Docker dan AWS S3.

## Prerequisites

- Docker & Docker Compose installed
- AWS S3 bucket created
- AWS Access Key & Secret Key ready

---

## 5-Minute Setup

### 1. Configure Environment (1 min)

```bash
cp .env.example .env
nano .env
```

**Edit these lines:**
```bash
# PostgreSQL
POSTGRES_PASSWORD=your_strong_password

# AWS S3 (REQUIRED)
AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxx
AWS_DEFAULT_REGION=ap-southeast-2
S3_BUCKET_NAME=db-backup-henotic
```

Save and exit.

### 2. Build & Start (2 min)

```bash
docker-compose build
docker-compose up -d
```

Wait for containers to be healthy:
```bash
docker ps
```

### 3. Test Backup (1 min)

```bash
./backup-with-s3.sh
```

Expected output:
```
✓ Local backup completed
✓ S3 upload completed
✓ S3 backup verified
```

### 4. Verify (30 sec)

```bash
# Check local
docker exec postgres-18 ls -lh /backups/daily/

# Check S3
docker exec postgres-backup-manager aws s3 ls s3://db-backup-henotic/postgres-backups/daily/
```

### 5. Setup Cron (30 sec)

```bash
crontab -e
```

Add this line (daily at 2 AM):
```bash
0 2 * * * cd $(pwd) && ./backup-with-s3.sh >> logs/cron.log 2>&1
```

Save and exit.

**Done!** ✅

---

## Quick Commands

### Backup
```bash
# Manual backup + S3
./backup-with-s3.sh

# Only local backup
docker exec postgres-18 /backup-scripts/backup.sh
```

### Restore
```bash
# From latest local
docker exec -it postgres-18 /backup-scripts/restore.sh --latest daily

# List available
docker exec postgres-18 /backup-scripts/restore.sh --list
```

### Monitor
```bash
# View logs
tail -f logs/backup_$(date +%Y%m%d).log
tail -f logs/cron.log

# Check containers
docker ps

# Check PostgreSQL
docker exec postgres-18 pg_isready
```

### Troubleshoot
```bash
# Container logs
docker logs postgres-18
docker logs postgres-backup-manager

# Test S3
docker exec postgres-backup-manager aws s3 ls s3://db-backup-henotic

# Restart
docker-compose restart
```

---

## Backup Flow

```
Backup Script → Local /backups/daily/ → Upload to S3 → Verify
     ↓                    ↓                    ↓           ↓
  backup.sh         1.0 KB backup       STANDARD_IA    Success
```

**Retention:**
- Local: Daily (7d), Weekly (30d), Monthly (365d)
- S3: Permanent (unless manual cleanup)

---

## File Structure

```
postgres-18/
├── backup-with-s3.sh        ← Run this for backup
├── docker-compose.yml
├── .env                     ← Your config
├── backups/daily/           ← Local backups
├── logs/                    ← All logs
├── backup-scripts/
└── backup-manager/
```

---

## Important Notes

⚠️ **Security:**
- Never commit `.env` to git
- Use strong passwords
- Rotate AWS keys regularly

✅ **Best Practices:**
- Test restore monthly
- Monitor logs weekly
- Review S3 costs monthly
- Keep local + S3 backups

📊 **Cost:**
- ~$0.10/month for 5GB (STANDARD_IA, Sydney region)

---

## Need Help?

- **Full guide**: [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)
- **Main README**: [README.md](README.md)
- **S3 details**: [S3_INTEGRATION.md](S3_INTEGRATION.md)
- **Logs**: `logs/` directory

---

**Quick Start Version**: 1.0
**Status**: ✅ Production Ready
