# PostgreSQL 18 with Automated Backup System

Setup lengkap PostgreSQL 18 dengan sistem backup otomatis, rotation policy, dan Docker support.

## Quick Start

### 1. Clone atau Setup Project

```bash
cd /path/to/postgres-18
cp .env.example .env
# Edit .env sesuai kebutuhan
```

### 2. Start PostgreSQL dengan Docker

```bash
docker-compose up -d
```

Services yang akan berjalan:
- **PostgreSQL 18**: Port 5432
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
│   ├── backup.sh         # Script backup utama
│   ├── restore.sh        # Script restore
│   ├── setup-cron.sh     # Setup cron job
│   └── README.md         # Dokumentasi backup system
├── backups/              # Backup storage (gitignored)
│   ├── daily/           # Daily backups (7 days retention)
│   ├── weekly/          # Weekly backups (30 days retention)
│   └── monthly/         # Monthly backups (365 days retention)
├── logs/                # Backup logs (gitignored)
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

#### Manual Backup

```bash
# Dari host
docker exec -it postgres-18 /backup-scripts/backup.sh

# Dari container
docker exec -it postgres-18 bash -c "cd /backup-scripts && ./backup.sh"
```

#### List Backups

```bash
docker exec -it postgres-18 /backup-scripts/restore.sh --list
```

#### Restore Database

```bash
# Restore dari backup terbaru
docker exec -it postgres-18 /backup-scripts/restore.sh --latest daily

# Restore dari file spesifik
docker exec -it postgres-18 /backup-scripts/restore.sh /backups/daily/backup_postgres_20231015_020000.dump
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

### Backup Types

1. **Single Database**: Backup database spesifik
2. **All Databases**: Set `POSTGRES_DB=all` untuk backup semua

### Storage Requirements

Estimate storage yang dibutuhkan:

```
Daily (7 copies) + Weekly (4 copies) + Monthly (12 copies) = 23 copies

Jika database size 1GB:
- Compressed backup: ~200MB
- Total storage needed: ~5GB (dengan buffer)
```

## Monitoring

### Check Backup Status

```bash
# View latest log
docker exec -it postgres-18 tail -f /logs/backup_$(date +%Y%m%d).log

# Check cron log
docker exec -it postgres-18 tail -f /logs/cron.log

# List all backups
docker exec -it postgres-18 ls -lh /backups/daily/
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

### Recovery Steps

1. **Stop aplikasi** yang menggunakan database
2. **List available backups**:
   ```bash
   docker exec -it postgres-18 /backup-scripts/restore.sh --list
   ```
3. **Restore dari backup**:
   ```bash
   docker exec -it postgres-18 /backup-scripts/restore.sh --latest daily
   ```
4. **Verify data**:
   ```bash
   docker exec -it postgres-18 psql -U postgres -d postgres -c "SELECT COUNT(*) FROM your_table;"
   ```
5. **Restart aplikasi**

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

## Support

Untuk issue atau pertanyaan:
1. Check logs di `logs/`
2. Review dokumentasi di `backup-scripts/README.md`
3. Check Docker logs: `docker-compose logs`

## License

Free to use and modify for your projects.
