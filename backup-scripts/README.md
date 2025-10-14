# PostgreSQL Backup & Restore System

Sistem backup otomatis untuk PostgreSQL dengan rotation policy dan scheduling via cron.

## Struktur Folder

```
postgres-18/
├── backup-scripts/          # Script backup & restore
│   ├── backup.sh           # Script utama backup
│   ├── restore.sh          # Script restore database
│   ├── setup-cron.sh       # Setup cron job otomatis
│   └── README.md           # Dokumentasi ini
├── backups/                # Folder backup
│   ├── daily/              # Backup harian (retention: 7 hari)
│   ├── weekly/             # Backup mingguan (retention: 30 hari)
│   └── monthly/            # Backup bulanan (retention: 365 hari)
├── logs/                   # Log backup
└── init-scripts/           # Init scripts PostgreSQL
```

## Fitur

- **Automated Backup**: Backup otomatis via cron job
- **Rotation Policy**:
  - Daily: Disimpan 7 hari
  - Weekly: Disimpan 30 hari (setiap Minggu)
  - Monthly: Disimpan 365 hari (tanggal 1 setiap bulan)
- **Compression**: Backup terkompresi untuk hemat storage
- **Logging**: Log lengkap setiap proses backup
- **Restore Tools**: Script restore yang mudah digunakan

## Quick Start

### 1. Setup Cron Job (Recommended)

Jalankan script setup interaktif:

```bash
./backup-scripts/setup-cron.sh
```

Script akan memandu Anda untuk:
- Mengatur jadwal backup (default: jam 2 pagi setiap hari)
- Konfigurasi koneksi PostgreSQL
- Set path backup dan log directory

### 2. Manual Backup

Untuk backup manual tanpa cron:

```bash
# Set environment variables
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=your_password
export POSTGRES_DB=your_database
export BACKUP_DIR=/path/to/backups
export LOG_DIR=/path/to/logs

# Run backup
./backup-scripts/backup.sh
```

### 3. Backup All Databases

Untuk backup semua database:

```bash
export POSTGRES_DB=all
./backup-scripts/backup.sh
```

## Restore Database

### List Available Backups

```bash
./backup-scripts/restore.sh --list
```

### Restore dari Backup Terbaru

```bash
# Restore dari daily backup terbaru
./backup-scripts/restore.sh --latest daily

# Restore dari weekly backup terbaru
./backup-scripts/restore.sh --latest weekly

# Restore dari monthly backup terbaru
./backup-scripts/restore.sh --latest monthly
```

### Restore dari File Spesifik

```bash
./backup-scripts/restore.sh /path/to/backup/backup_mydb_20231015_020000.dump
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_HOST` | localhost | PostgreSQL host |
| `POSTGRES_PORT` | 5432 | PostgreSQL port |
| `POSTGRES_USER` | postgres | PostgreSQL username |
| `POSTGRES_PASSWORD` | - | PostgreSQL password |
| `POSTGRES_DB` | postgres | Database name (or 'all') |
| `BACKUP_DIR` | /backups | Backup directory path |
| `LOG_DIR` | /logs | Log directory path |

## Docker Integration

### Untuk PostgreSQL di Docker:

1. **Mount volumes** untuk backup dan logs:

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:18
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
      - ./logs:/logs
      - ./backup-scripts:/backup-scripts
    environment:
      POSTGRES_PASSWORD: your_password
```

2. **Jalankan backup dari container**:

```bash
# Masuk ke container
docker exec -it postgres_container bash

# Jalankan backup
cd /backup-scripts
./backup.sh
```

3. **Setup cron di host atau container**:

```bash
# Di host (backup dari luar container)
0 2 * * * docker exec postgres_container /backup-scripts/backup.sh

# Atau di container (setup cron di dalam container)
docker exec -it postgres_container bash
./backup-scripts/setup-cron.sh
```

## Maintenance

### Cek Status Backup

```bash
# Lihat cron jobs yang aktif
crontab -l

# Lihat log terbaru
tail -f logs/backup_$(date +%Y%m%d).log

# Lihat log cron
tail -f logs/cron.log
```

### Manual Cleanup

```bash
# Hapus backup lama secara manual
find backups/daily -name "backup_*.dump" -mtime +7 -delete
find backups/weekly -name "backup_*.dump" -mtime +30 -delete
find backups/monthly -name "backup_*.dump" -mtime +365 -delete
```

### Test Restore

Sangat direkomendasikan untuk test restore secara berkala:

```bash
# Create test database
createdb test_restore

# Restore ke test database
export POSTGRES_DB=test_restore
./backup-scripts/restore.sh --latest daily

# Verify data
psql -d test_restore -c "SELECT COUNT(*) FROM your_table;"

# Cleanup
dropdb test_restore
```

## Troubleshooting

### Cron tidak jalan

1. Cek cron service:
```bash
# Linux
sudo systemctl status cron

# macOS
sudo launchctl list | grep cron
```

2. Cek permission script:
```bash
ls -l backup-scripts/*.sh
# Harus executable (-rwxr-xr-x)
```

3. Cek log cron:
```bash
tail -f logs/cron.log
```

### Backup gagal - Authentication failed

Pastikan:
- Password benar di `.backup.env`
- User memiliki permission untuk backup
- PostgreSQL menerima koneksi dari host

### Space penuh

Adjust retention policy di `backup.sh`:

```bash
DAILY_RETENTION=7    # Kurangi jika perlu
WEEKLY_RETENTION=30
MONTHLY_RETENTION=365
```

## Best Practices

1. **Test restore secara berkala** (minimal bulanan)
2. **Monitor log** untuk memastikan backup sukses
3. **Store backup di offsite** (cloud storage, server lain)
4. **Encrypt sensitive backups**
5. **Document restore procedure** untuk disaster recovery
6. **Monitor disk space** untuk backup directory

## Security Notes

- File `.backup.env` berisi password, pastikan permission 600
- Jangan commit `.backup.env` ke git
- Gunakan strong password untuk PostgreSQL
- Rotate backup ke offsite storage securely

## Support

Untuk pertanyaan atau issue, silakan dokumentasikan:
- Output log backup
- PostgreSQL version
- OS dan version
- Error messages lengkap
