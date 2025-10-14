# Backup Manager - AWS S3 Integration

Sidecar container untuk mengelola upload dan download backup PostgreSQL ke/dari AWS S3.

## Overview

Container ini berisi AWS CLI dan script-script untuk:
- Upload backup otomatis ke S3 setelah backup lokal selesai
- Download backup dari S3 untuk restore
- List backup yang tersedia di S3
- SSE-S3 encryption untuk semua backup

## Architecture

```
┌─────────────────────────┐
│   postgres:18-alpine    │
│   - Database engine     │
│   - Local backup        │
└───────────┬─────────────┘
            │
            │ Shared Volumes:
            │ /backups, /logs
            │
┌───────────▼─────────────┐
│   backup-manager        │
│   - AWS CLI             │
│   - S3 upload/download  │
│   - Encryption (SSE-S3) │
└─────────────────────────┘
            │
            │ HTTPS (TLS)
            │
┌───────────▼─────────────┐
│   AWS S3                │
│   - Offsite storage     │
│   - Disaster recovery   │
└─────────────────────────┘
```

## Components

### Dockerfile
- Base: Alpine Linux 3.19
- AWS CLI v2
- PostgreSQL client tools
- Timezone: Australia/Sydney

### Scripts

#### 1. upload-to-s3.sh
Upload backup files ke S3 dengan fitur:
- Auto-detect backup type (daily/weekly/monthly)
- SSE-S3 encryption (AES256)
- Storage class: STANDARD_IA (cost-efficient)
- Retry logic: 3x with exponential backoff
- Upload verification
- Detailed logging

**Usage:**
```bash
# Upload specific file
docker exec postgres-backup-manager /s3-scripts/upload-to-s3.sh /backups/daily/backup_xxx.dump

# Upload latest daily backup
docker exec postgres-backup-manager /s3-scripts/upload-to-s3.sh --upload-latest daily
```

#### 2. download-from-s3.sh
Download backup files dari S3:
- List available backups
- Download specific file
- Download latest by type
- Download to temporary location
- Auto cleanup

**Usage:**
```bash
# List all S3 backups
docker exec postgres-backup-manager /s3-scripts/download-from-s3.sh --list

# List specific type
docker exec postgres-backup-manager /s3-scripts/download-from-s3.sh --list daily

# Download latest daily backup
docker exec postgres-backup-manager /s3-scripts/download-from-s3.sh --download-latest daily

# Download specific file
docker exec postgres-backup-manager /s3-scripts/download-from-s3.sh --download s3://bucket/path/to/backup.dump
```

#### 3. s3-helper.sh
Common functions untuk S3 operations:
- Check S3 connectivity
- Get bucket info
- Test upload
- Calculate storage usage

## Configuration

### Environment Variables

Required:
```bash
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
S3_BUCKET_NAME=your-bucket-name
```

Optional (with defaults):
```bash
AWS_DEFAULT_REGION=ap-southeast-2
S3_BACKUP_PREFIX=postgres-backups
S3_STORAGE_CLASS=STANDARD_IA
BACKUP_DIR=/backups
LOG_DIR=/logs
```

### S3 Bucket Structure

Backups disimpan dengan struktur:
```
s3://db-backup-henotic/
└── postgres-backups/
    ├── daily/
    │   ├── backup_postgres_20231015_020000.dump
    │   └── backup_postgres_20231016_020000.dump
    ├── weekly/
    │   └── backup_postgres_20231015_020000.dump
    └── monthly/
        └── backup_postgres_20231001_020000.dump
```

## AWS IAM Policy

Minimal IAM policy untuk S3 access:

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

## Usage Examples

### Manual Upload

```bash
# Upload backup yang baru dibuat
docker exec postgres-18 /backup-scripts/backup.sh
# Upload otomatis terjadi setelah backup selesai
```

### Manual Download & Restore

```bash
# List available backups di S3
docker exec postgres-18 /backup-scripts/restore.sh --list-s3

# Restore dari S3 (latest daily)
docker exec postgres-18 /backup-scripts/restore.sh --from-s3 daily

# Restore dari specific S3 file
docker exec postgres-18 /backup-scripts/restore.sh --from-s3-file s3://db-backup-henotic/postgres-backups/daily/backup_xxx.dump
```

### Check S3 Status

```bash
# Check if backup-manager is running
docker ps | grep backup-manager

# View logs
docker logs postgres-backup-manager

# Test S3 connectivity
docker exec postgres-backup-manager aws s3 ls s3://db-backup-henotic

# Check S3 storage usage
docker exec postgres-backup-manager aws s3 ls s3://db-backup-henotic/postgres-backups/ --recursive --human-readable --summarize
```

## Security

### Encryption
- **In-Transit**: HTTPS/TLS untuk semua komunikasi dengan S3
- **At-Rest**: SSE-S3 (AES-256) encryption untuk semua objects

### Credentials
- AWS credentials stored di `.env` file (git-ignored)
- Environment variables only (tidak hardcoded)
- Recommended: IAM role dengan least-privilege

### Best Practices
1. Gunakan IAM user dedicated untuk backup
2. Enable MFA untuk IAM user
3. Rotate access keys secara berkala
4. Enable S3 bucket versioning
5. Enable S3 access logging
6. Set bucket policy untuk restrict access

## Monitoring

### Log Files

```bash
# S3 upload logs
tail -f logs/s3_upload_$(date +%Y%m%d).log

# S3 download logs
tail -f logs/s3_download_$(date +%Y%m%d).log

# Backup logs (includes S3 status)
tail -f logs/backup_$(date +%Y%m%d).log
```

### Health Check

```bash
# Check container health
docker inspect postgres-backup-manager | grep -A 10 Health

# Test AWS CLI
docker exec postgres-backup-manager aws --version

# Test S3 access
docker exec postgres-backup-manager aws s3 ls s3://db-backup-henotic
```

## Troubleshooting

### Upload Fails

```bash
# Check AWS credentials
docker exec postgres-backup-manager env | grep AWS

# Test S3 connectivity
docker exec postgres-backup-manager aws s3 ls

# Check logs
cat logs/s3_upload_$(date +%Y%m%d).log
```

### Download Fails

```bash
# Verify backup exists in S3
docker exec postgres-backup-manager aws s3 ls s3://db-backup-henotic/postgres-backups/daily/

# Check download logs
cat logs/s3_download_$(date +%Y%m%d).log

# Check disk space for downloads
docker exec postgres-backup-manager df -h /tmp
```

### Container Won't Start

```bash
# Check container logs
docker logs postgres-backup-manager

# Rebuild container
docker-compose build backup-manager
docker-compose up -d backup-manager
```

## Cost Optimization

### Storage Classes

- **STANDARD**: Frequent access, higher cost
- **STANDARD_IA**: Infrequent access, lower cost (recommended for backups)
- **GLACIER**: Archive, lowest cost, slower retrieval

### Lifecycle Rules

Setup S3 lifecycle untuk auto-transition:

```bash
# Transition to cheaper storage over time
Day 0-30: STANDARD_IA (immediate access)
Day 31-90: GLACIER_IR (instant retrieval)
Day 91+: GLACIER (flexible retrieval)
Day 730+: Delete
```

### Estimated Costs (Sydney Region)

Assuming 200MB compressed backup per day:

```
Daily backups (7 days): 1.4 GB
Weekly backups (4 weeks): 800 MB
Monthly backups (12 months): 2.4 GB
Total: ~5 GB

STANDARD_IA: $0.019/GB/month
Monthly cost: ~$0.10 USD/month

With data transfer (download): +$0.11/GB
```

## Maintenance

### Regular Tasks

**Weekly:**
- Check upload logs for failures
- Verify latest backup exists in S3

**Monthly:**
- Review S3 storage usage
- Test restore from S3
- Rotate AWS access keys

**Quarterly:**
- Review IAM permissions
- Update Alpine/AWS CLI versions
- Test disaster recovery procedure

### Updates

```bash
# Rebuild with latest Alpine/AWS CLI
docker-compose build --no-cache backup-manager
docker-compose up -d backup-manager

# Verify new version
docker exec postgres-backup-manager aws --version
```

## Support

For issues:
1. Check logs in `/logs/` directory
2. Verify AWS credentials in `.env`
3. Test S3 connectivity manually
4. Check container health status

## References

- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [S3 Storage Classes](https://aws.amazon.com/s3/storage-classes/)
- [S3 Encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/serv-side-encryption.html)
