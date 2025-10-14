# PostgreSQL 18 with Automated Backup System + AWS S3

Setup lengkap PostgreSQL 18 dengan sistem backup otomatis, AWS S3 offsite backup, rotation policy, dan Docker support.

## 📚 Documentation

- **⚡ [Quick Start Guide](QUICK_START.md)** - 5 minute setup
- **📖 [Complete Installation Guide](INSTALLATION_GUIDE.md)** - Step-by-step from scratch
- **☁️ [S3 Integration Details](S3_INTEGRATION.md)** - Technical architecture
- **🔧 [Backup Manager README](backup-manager/README.md)** - S3 operations

## Quick Start

### 1. Clone atau Setup Project

```bash
cd /path/to/postgres-18
cp .env.example .env
# Edit .env sesuai kebutuhan
```

### 2. Configure AWS S3 (untuk offsite backup)

Edit file `.env` dan tambahkan AWS credentials:

```bash
# AWS S3 Configuration
AWS_ACCESS_KEY_ID=your_aws_access_key_id
AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key
AWS_DEFAULT_REGION=ap-southeast-2
S3_BUCKET_NAME=db-backup-henotic
S3_BACKUP_PREFIX=postgres-backups
S3_STORAGE_CLASS=STANDARD_IA
S3_UPLOAD_ENABLED=true
```

**Note**: Jika tidak ingin menggunakan S3, set `S3_UPLOAD_ENABLED=false`

### 3. Start PostgreSQL dengan Docker

```bash
docker-compose up -d
```

Services yang akan berjalan:
- **PostgreSQL 18**: Port 5432
- **backup-manager**: AWS S3 integration untuk offsite backups
- **pgAdmin**: Port 5050 (optional, untuk management UI)

### 3. Verify PostgreSQL Running

```bash
docker-compose ps
docker exec -it postgres-18 psql -U postgres -d postgres -c "SELECT version();"
```

### 4. Setup Automated Backup

#### Option A: Backup dari Host

```bash
cd backup-scripts
./setup-cron.sh
```

#### Option B: Backup dari Container

```bash
docker exec -it postgres-18 bash
cd /backup-scripts
./setup-cron.sh
```

## Struktur Project

```
postgres-18/
├── docker-compose.yml       # Docker compose configuration
├── .env.example            # Environment variables template
├── .env                    # Your environment variables (gitignored)
├── .gitignore             # Git ignore rules
├── README.md              # Dokumentasi ini
├── backup-scripts/        # Backup & restore scripts
│   ├── backup.sh         # Script backup utama (dengan S3 integration)
│   ├── restore.sh        # Script restore (dengan S3 support)
│   ├── setup-cron.sh     # Setup cron job
│   └── README.md         # Dokumentasi backup system
├── backup-manager/        # S3 Integration (Sidecar container)
│   ├── Dockerfile        # Alpine + AWS CLI
│   ├── scripts/          # S3 scripts
│   │   ├── upload-to-s3.sh      # Upload backups to S3
│   │   ├── download-from-s3.sh  # Download from S3
│   │   └── s3-helper.sh         # Common S3 functions
│   └── README.md         # S3 integration documentation
├── backups/              # Backup storage (gitignored)
│   ├── daily/           # Daily backups (7 days retention)
│   ├── weekly/          # Weekly backups (30 days retention)
│   └── monthly/         # Monthly backups (365 days retention)
├── logs/                # Logs (gitignored)
│   ├── backup_*.log     # Backup logs
│   ├── s3_upload_*.log  # S3 upload logs
│   └── s3_download_*.log # S3 download logs
└── init-scripts/        # PostgreSQL init scripts
```

## Usage

### Accessing PostgreSQL

#### Via psql CLI

```bash
# From host
docker exec -it postgres-18 psql -U postgres -d postgres

# From container
docker exec -it postgres-18 bash
psql -U postgres -d postgres
```

#### Via pgAdmin

1. Open browser: http://localhost:5050
2. Login dengan credentials dari `.env`
3. Add server:
   - Host: postgres
   - Port: 5432
   - Username: postgres
   - Password: dari `.env`

### Backup Operations

#### 🚀 Automated Backup with S3 Upload (Recommended)

```bash
# One command - creates backup + uploads to S3
./backup-with-s3.sh
```

This script automatically:
1. ✅ Creates local PostgreSQL backup
2. ✅ Uploads to S3 with encryption
3. ✅ Verifies upload success
4. ✅ Logs everything

**Use this for cron jobs!**

#### Manual Backup (Local Only)

```bash
# Backup without S3 upload
docker exec -it postgres-18 /backup-scripts/backup.sh
```

#### List Backups

```bash
# Local backups
docker exec -it postgres-18 /backup-scripts/restore.sh --list
```

#### Restore Database

```bash
# Restore dari backup terbaru (local)
docker exec -it postgres-18 /backup-scripts/restore.sh --latest daily

# Restore dari file spesifik (local)
docker exec -it postgres-18 /backup-scripts/restore.sh /backups/daily/backup_postgres_20231015_020000.dump
```

### S3 Operations (Offsite Backup)

#### List S3 Backups

```bash
# List all backups di S3
docker exec -it postgres-18 /backup-scripts/restore.sh --list-s3

# List specific type
docker exec -it postgres-18 /backup-scripts/restore.sh --list-s3 daily
```

#### Restore from S3

```bash
# Restore latest backup dari S3
docker exec -it postgres-18 /backup-scripts/restore.sh --from-s3 daily

# Restore specific file dari S3
docker exec -it postgres-18 /backup-scripts/restore.sh --from-s3-file s3://db-backup-henotic/postgres-backups/daily/backup_xxx.dump
```

#### Manual S3 Upload

```bash
# Upload specific backup ke S3
docker exec postgres-backup-manager /s3-scripts/upload-to-s3.sh /backups/daily/backup_xxx.dump

# Upload latest daily backup
docker exec postgres-backup-manager /s3-scripts/upload-to-s3.sh --upload-latest daily
```

#### Check S3 Status

```bash
# List files di S3
docker exec postgres-backup-manager aws s3 ls s3://db-backup-henotic/postgres-backups/ --recursive

# Check S3 storage usage
docker exec postgres-backup-manager aws s3 ls s3://db-backup-henotic/postgres-backups/ --recursive --human-readable --summarize

# Test S3 connectivity
docker exec postgres-backup-manager aws s3 ls s3://db-backup-henotic
```

### Docker Operations

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f postgres

# Restart PostgreSQL
docker-compose restart postgres

# Remove everything (including data)
docker-compose down -v
```

## Configuration

### Environment Variables

Edit file `.env`:

```bash
# PostgreSQL Configuration
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_secure_password_here
POSTGRES_DB=postgres
POSTGRES_PORT=5432

# pgAdmin Configuration
PGADMIN_EMAIL=admin@example.com
PGADMIN_PASSWORD=admin_password
PGADMIN_PORT=5050

# Backup Configuration
POSTGRES_HOST=localhost
BACKUP_DIR=/backups
LOG_DIR=/logs

# AWS S3 Configuration (Offsite Backup)
AWS_ACCESS_KEY_ID=your_aws_access_key_id
AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key
AWS_DEFAULT_REGION=ap-southeast-2
S3_BUCKET_NAME=db-backup-henotic
S3_BACKUP_PREFIX=postgres-backups
S3_STORAGE_CLASS=STANDARD_IA
S3_UPLOAD_ENABLED=true
```

### AWS S3 Setup

#### 1. Create S3 Bucket

```bash
# Via AWS CLI
aws s3 mb s3://db-backup-henotic --region ap-southeast-2

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
    --bucket db-backup-henotic \
    --versioning-configuration Status=Enabled

# Enable default encryption
aws s3api put-bucket-encryption \
    --bucket db-backup-henotic \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'
```

#### 2. Create IAM User

Buat IAM user dedicated untuk backup dengan policy minimal:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::db-backup-henotic",
        "arn:aws:s3:::db-backup-henotic/*"
      ]
    }
  ]
}
```

#### 3. Get AWS Credentials

- Login ke AWS Console
- Go to IAM > Users > [your-backup-user] > Security credentials
- Create access key
- Copy Access Key ID dan Secret Access Key
- Paste ke `.env` file

#### 4. S3 Lifecycle Rules (Optional)

Setup automatic transition untuk cost optimization:

```bash
aws s3api put-bucket-lifecycle-configuration \
    --bucket db-backup-henotic \
    --lifecycle-configuration file://lifecycle.json
```

`lifecycle.json`:
```json
{
  "Rules": [
    {
      "Id": "BackupLifecycle",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "postgres-backups/"
      },
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "GLACIER_IR"
        },
        {
          "Days": 365,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ],
      "Expiration": {
        "Days": 730
      }
    }
  ]
}
```

### Backup Schedule

Default: Setiap hari jam 2 pagi

Untuk mengubah:
```bash
crontab -e
# Edit jadwal cron sesuai kebutuhan
```

### Retention Policy

Edit di `backup-scripts/backup.sh`:

```bash
DAILY_RETENTION=7      # hari
WEEKLY_RETENTION=30    # hari
MONTHLY_RETENTION=365  # hari
```

## Backup Strategy

### Automatic Rotation

- **Daily**: Backup setiap hari, disimpan 7 hari
- **Weekly**: Backup setiap Minggu, disimpan 30 hari
- **Monthly**: Backup tanggal 1 tiap bulan, disimpan 365 hari

### Backup Flow (with S3)

```
1. Cron trigger backup.sh (2 AM daily)
   ↓
2. Create local backup → /backups/daily/
   ↓
3. Compress with pg_dump (level 9)
   ↓
4. Upload to S3 (SSE-S3 encrypted) ← OFFSITE BACKUP
   ↓
5. Cleanup old local backups (rotation policy)
   ↓
6. Log results
```

**Benefits:**
- ✅ Local backup = Fast restore
- ✅ S3 backup = Disaster recovery
- ✅ Encrypted in-transit dan at-rest
- ✅ Cost-efficient dengan STANDARD_IA storage

### Backup Types

1. **Single Database**: Backup database spesifik
2. **All Databases**: Set `POSTGRES_DB=all` untuk backup semua

### Storage Requirements

#### Local Storage

```
Daily (7 copies) + Weekly (4 copies) + Monthly (12 copies) = 23 copies

Jika database size 1GB:
- Compressed backup: ~200MB
- Total local storage: ~5GB (dengan buffer)
```

#### S3 Storage

```
Same structure as local: ~5GB

STANDARD_IA Pricing (Sydney):
- Storage: $0.019/GB/month
- Monthly cost: ~$0.10 USD/month

With occasional restore (1GB):
- Data transfer out: $0.11/GB
- Per restore cost: ~$0.11 USD
```

## Monitoring

### Check Backup Status

```bash
# View latest backup log
docker exec -it postgres-18 tail -f /logs/backup_$(date +%Y%m%d).log

# View S3 upload log
docker exec -it postgres-18 tail -f /logs/s3_upload_$(date +%Y%m%d).log

# Check cron log
docker exec -it postgres-18 tail -f /logs/cron.log

# List all local backups
docker exec -it postgres-18 ls -lh /backups/daily/

# List all S3 backups
docker exec postgres-backup-manager aws s3 ls s3://db-backup-henotic/postgres-backups/ --recursive --human-readable

# Check backup-manager health
docker ps | grep backup-manager
docker logs postgres-backup-manager --tail 50
```

### Alerts

Setup alert jika backup gagal (customize di `backup-scripts/backup.sh`):

```bash
send_notification() {
    local status=$1
    local message=$2
    # Add your notification method:
    # - Email
    # - Slack
    # - Telegram
    # - etc.
}
```

## Disaster Recovery

### Recovery Scenarios

#### Scenario 1: Local Server Available (Quick Recovery)

1. **Stop aplikasi** yang menggunakan database
2. **List available local backups**:
   ```bash
   docker exec -it postgres-18 /backup-scripts/restore.sh --list
   ```
3. **Restore dari local backup**:
   ```bash
   docker exec -it postgres-18 /backup-scripts/restore.sh --latest daily
   ```
4. **Verify data**:
   ```bash
   docker exec -it postgres-18 psql -U postgres -d postgres -c "SELECT COUNT(*) FROM your_table;"
   ```
5. **Restart aplikasi**

**Recovery Time**: ~5-10 minutes

#### Scenario 2: Complete Server Loss (Disaster Recovery from S3)

1. **Setup new server** dengan Docker
2. **Clone repository** dan configure `.env`
3. **Start containers**:
   ```bash
   docker-compose up -d
   ```
4. **List S3 backups**:
   ```bash
   docker exec -it postgres-18 /backup-scripts/restore.sh --list-s3
   ```
5. **Restore dari S3**:
   ```bash
   # Restore latest backup
   docker exec -it postgres-18 /backup-scripts/restore.sh --from-s3 daily

   # Or specific backup
   docker exec -it postgres-18 /backup-scripts/restore.sh --from-s3-file s3://db-backup-henotic/postgres-backups/monthly/backup_xxx.dump
   ```
6. **Verify data**:
   ```bash
   docker exec -it postgres-18 psql -U postgres -d postgres -c "SELECT COUNT(*) FROM your_table;"
   ```
7. **Resume operations**

**Recovery Time**: ~20-30 minutes (including download time)

#### Scenario 3: Point-in-Time Recovery

1. **Identify target restore point** berdasarkan timestamp
2. **List backups**:
   ```bash
   # Local
   docker exec -it postgres-18 ls -lh /backups/daily/

   # S3
   docker exec -it postgres-18 /backup-scripts/restore.sh --list-s3
   ```
3. **Restore specific backup**:
   ```bash
   # Local
   docker exec -it postgres-18 /backup-scripts/restore.sh /backups/daily/backup_postgres_20231015_143000.dump

   # S3
   docker exec -it postgres-18 /backup-scripts/restore.sh --from-s3-file s3://db-backup-henotic/postgres-backups/daily/backup_postgres_20231015_143000.dump
   ```

### Test Recovery (Recommended)

Test restore secara berkala:

```bash
# Create test database
docker exec -it postgres-18 createdb -U postgres test_restore

# Restore
POSTGRES_DB=test_restore docker exec -it postgres-18 /backup-scripts/restore.sh --latest daily

# Verify
docker exec -it postgres-18 psql -U postgres -d test_restore -c "\dt"

# Cleanup
docker exec -it postgres-18 dropdb -U postgres test_restore
```

## Security

### Best Practices

1. **Strong Passwords**: Gunakan password yang kuat
2. **File Permissions**: `.backup.env` harus chmod 600
3. **Network Security**: Gunakan firewall untuk port PostgreSQL
4. **Backup Encryption**: Encrypt backup untuk data sensitif
5. **Offsite Storage**: Copy backup ke cloud storage

### Secure Backup

Encrypt backup:

```bash
# Encrypt
gpg --encrypt --recipient your@email.com backup.dump

# Decrypt
gpg --decrypt backup.dump.gpg > backup.dump
```

## Troubleshooting

### Container tidak start

```bash
docker-compose logs postgres
# Check error messages
```

### Connection refused

```bash
# Check if PostgreSQL is running
docker-compose ps

# Check PostgreSQL logs
docker-compose logs postgres

# Test connection
docker exec -it postgres-18 pg_isready -U postgres
```

### Backup fails

```bash
# Check permissions
docker exec -it postgres-18 ls -la /backup-scripts/

# Check logs
docker exec -it postgres-18 cat /logs/backup_$(date +%Y%m%d).log

# Test manual backup
docker exec -it postgres-18 /backup-scripts/backup.sh
```

### Disk space full

```bash
# Check disk usage
docker exec -it postgres-18 df -h /backups

# Manual cleanup old backups
docker exec -it postgres-18 find /backups/daily -mtime +7 -delete

# Adjust retention policy
```

## Maintenance

### Regular Tasks

- [ ] Weekly: Check backup logs
- [ ] Monthly: Test restore procedure
- [ ] Quarterly: Review retention policy
- [ ] Yearly: Update PostgreSQL version

### Updates

Update PostgreSQL version:

```bash
# Backup first!
docker exec -it postgres-18 /backup-scripts/backup.sh

# Update docker-compose.yml (change image version)
# Then:
docker-compose down
docker-compose pull
docker-compose up -d
```

## Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Docker PostgreSQL Official Image](https://hub.docker.com/_/postgres)
- [pg_dump Documentation](https://www.postgresql.org/docs/current/app-pgdump.html)
- [Backup Scripts README](backup-scripts/README.md)
- [Backup Manager S3 Integration](backup-manager/README.md)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)

## Support

Untuk issue atau pertanyaan:
1. Check logs di `logs/`
2. Review dokumentasi di `backup-scripts/README.md`
3. Check Docker logs: `docker-compose logs`

## License

Free to use and modify for your projects.
