# Permission Setup Guide

Panduan lengkap untuk setup dan fix permission issue pada PostgreSQL backup system.

---

## Problem Overview

### Common Permission Issues

**Issue 1: Cron Cannot Write to Logs**
```bash
# Error:
bash: logs/cron.log: Permission denied
```

**Root Cause:**
- Logs folder owned by `root`
- Cron runs as regular user (e.g., `jam`)
- User cannot write to root-owned directories

**Issue 2: Backup Script Not Executable**
```bash
# Error:
bash: ./backup-with-s3.sh: Permission denied
```

**Root Cause:**
- Script does not have execute permission
- Need `chmod +x` to make executable

---

## Quick Fix (Automatic)

### Use Fix-Permissions Script

We've created an automated script to fix all permissions:

```bash
cd /home/jam/henotic/docker-files/postgres_18
sudo ./fix-permissions.sh jam
```

**What it does:**
1. ✅ Changes ownership of all directories to user `jam`
2. ✅ Sets correct permissions for directories (755)
3. ✅ Sets correct permissions for files (644)
4. ✅ Makes all scripts executable (755)
5. ✅ Verifies and reports results

**Output:**
```
╔════════════════════════════════════════════════════════╗
║  PostgreSQL Backup - Permission Fix                   ║
╚════════════════════════════════════════════════════════╝

User: jam
Group: jam
Working Directory: /home/jam/henotic/docker-files/postgres_18

=== Fixing Directory Permissions ===

Fixing: Backups directory
  ✓ Directory ownership: jam:jam
  ✓ Directory permission: 755

Fixing: Logs directory
  ✓ Directory ownership: jam:jam
  ✓ Directory permission: 755

=== Fixing Script Permissions (Make Executable) ===

Fixing: Main backup script
  ✓ Script ownership: jam:jam
  ✓ Script permission: 755 (executable)

=== Permission Fix Completed Successfully! ===
```

---

## Manual Fix (Step-by-Step)

If you prefer to fix manually:

### 1. Fix Directory Ownership

```bash
cd /home/jam/henotic/docker-files/postgres_18

# Fix all directories at once
sudo chown -R jam:jam backups/
sudo chown -R jam:jam logs/
sudo chown -R jam:jam backup-scripts/
sudo chown -R jam:jam backup-manager/
```

### 2. Fix Directory Permissions

```bash
# Directories: 755 (rwxr-xr-x)
sudo chmod 755 backups/
sudo chmod 755 backups/daily/
sudo chmod 755 backups/weekly/
sudo chmod 755 backups/monthly/
sudo chmod 755 logs/
sudo chmod 755 backup-scripts/
sudo chmod 755 backup-manager/
sudo chmod 755 backup-manager/scripts/
```

### 3. Fix File Permissions

```bash
# Log files: 644 (rw-r--r--)
sudo chmod 644 logs/*.log 2>/dev/null || true

# Backup files: 644
sudo chmod 644 backups/daily/*.dump 2>/dev/null || true
sudo chmod 644 backups/weekly/*.dump 2>/dev/null || true
sudo chmod 644 backups/monthly/*.dump 2>/dev/null || true
```

### 4. Fix Script Permissions (Make Executable)

```bash
# Main scripts: 755 (rwxr-xr-x)
chmod +x backup-with-s3.sh
chmod +x setup-backup.sh
chmod +x fix-permissions.sh

# Backup scripts
chmod +x backup-scripts/backup.sh
chmod +x backup-scripts/restore.sh
chmod +x backup-scripts/setup-cron.sh

# Backup-manager scripts
chmod +x backup-manager/scripts/upload-to-s3.sh
chmod +x backup-manager/scripts/download-from-s3.sh
chmod +x backup-manager/scripts/s3-helper.sh
```

---

## Verification

### 1. Check Directory Ownership & Permissions

```bash
ls -ld backups logs backup-scripts backup-manager
```

**Expected output:**
```
drwxr-xr-x 5 jam jam 4096 Oct 14 07:00 backups
drwxr-xr-x 2 jam jam 4096 Oct 14 07:00 logs
drwxr-xr-x 2 jam jam 4096 Oct 14 06:00 backup-scripts
drwxr-xr-x 3 jam jam 4096 Oct 14 06:00 backup-manager
```

### 2. Check Script Permissions

```bash
ls -lh *.sh
```

**Expected output:**
```
-rwxr-xr-x 1 jam jam 3.5K Oct 14 12:00 backup-with-s3.sh
-rwxr-xr-x 1 jam jam 6.2K Oct 14 12:00 setup-backup.sh
-rwxr-xr-x 1 jam jam 4.1K Oct 14 14:00 fix-permissions.sh
```

### 3. Test Write Permission to Logs

```bash
touch logs/test.log
echo "test" >> logs/test.log
cat logs/test.log
rm logs/test.log
```

**If successful:** No errors, file created and removed.

### 4. Test Script Execution

```bash
./backup-with-s3.sh >> logs/test-run.log 2>&1
cat logs/test-run.log
```

**If successful:** Backup runs without permission errors.

---

## Permission Reference

### Recommended Permissions

| Path | Type | Owner | Permission | Octal | Description |
|------|------|-------|------------|-------|-------------|
| `backups/` | Directory | jam:jam | `drwxr-xr-x` | 755 | Backup storage |
| `backups/daily/` | Directory | jam:jam | `drwxr-xr-x` | 755 | Daily backups |
| `logs/` | Directory | jam:jam | `drwxr-xr-x` | 755 | Log files |
| `backup-scripts/` | Directory | jam:jam | `drwxr-xr-x` | 755 | Scripts directory |
| `*.log` | File | jam:jam | `-rw-r--r--` | 644 | Log files |
| `*.dump` | File | jam:jam | `-rw-r--r--` | 644 | Backup files |
| `*.sh` | Script | jam:jam | `-rwxr-xr-x` | 755 | Executable scripts |
| `.env` | File | jam:jam | `-rw-------` | 600 | Sensitive config |

### Permission Explanation

**755 (rwxr-xr-x)** - Directories & Scripts
- Owner: read, write, execute
- Group: read, execute
- Others: read, execute

**644 (rw-r--r--)** - Regular Files
- Owner: read, write
- Group: read
- Others: read

**600 (rw-------)** - Sensitive Files (.env)
- Owner: read, write
- Group: no access
- Others: no access

---

## Prevention Guide

### Best Practices

#### 1. **Always Run Scripts as Regular User**

```bash
# ❌ DON'T run as root (creates root-owned files)
sudo ./backup-with-s3.sh

# ✅ DO run as regular user
./backup-with-s3.sh
```

#### 2. **Use Cron as Regular User**

```bash
# ❌ DON'T use root crontab
sudo crontab -e

# ✅ DO use user crontab
crontab -e
```

#### 3. **Docker Volume Permissions**

If using Docker volumes, ensure proper permissions:

```yaml
# docker-compose.yml
volumes:
  - ./backups:/backups
  - ./logs:/logs

# After first run, fix permissions:
# sudo chown -R $USER:$USER backups/ logs/
```

#### 4. **Initial Setup Checklist**

After cloning/deploying:

```bash
# 1. Set ownership
sudo chown -R $USER:$USER .

# 2. Or use fix script
sudo ./fix-permissions.sh $USER

# 3. Verify
ls -ld backups logs
```

---

## Troubleshooting

### Issue: "Permission denied" when running script

**Solution:**
```bash
chmod +x script-name.sh
```

### Issue: "Cannot create directory: Permission denied"

**Solution:**
```bash
sudo chown -R $USER:$USER directory-name/
chmod 755 directory-name/
```

### Issue: Cron creates root-owned files

**Cause:** Running script with `sudo` in crontab

**Solution:**
```bash
# Edit crontab
crontab -e

# Remove sudo from command
# Before: sudo ./backup-with-s3.sh
# After:  ./backup-with-s3.sh
```

### Issue: Docker container creates root-owned files

**Solution:**
```bash
# After backup, fix ownership
sudo chown -R $USER:$USER backups/ logs/

# Or add to cron:
0 2 * * * cd /path/to/project && ./backup-with-s3.sh && sudo chown -R $USER:$USER backups/ logs/
```

---

## Automation

### Run Permission Fix After Each Deployment

Add to deployment script:

```bash
#!/bin/bash
# deploy.sh

cd /home/jam/henotic/docker-files/postgres_18

# Pull latest changes
git pull

# Fix permissions
sudo ./fix-permissions.sh jam

# Restart services
docker-compose restart

echo "Deployment complete!"
```

### Schedule Weekly Permission Check

Add to crontab:

```bash
# Check and fix permissions every Sunday at 3 AM
0 3 * * 0 cd /home/jam/henotic/docker-files/postgres_18 && sudo ./fix-permissions.sh jam >> logs/permission-fix.log 2>&1
```

---

## Security Considerations

### 1. **Sensitive Files**

Protect `.env` file:

```bash
chmod 600 .env
```

Verify:
```bash
ls -lh .env
# Should show: -rw------- (600)
```

### 2. **Backup Files**

If backups contain sensitive data, restrict access:

```bash
chmod 640 backups/daily/*.dump
chmod 640 backups/weekly/*.dump
chmod 640 backups/monthly/*.dump
```

### 3. **Log Files**

If logs contain sensitive info:

```bash
chmod 640 logs/*.log
```

---

## Quick Commands Reference

```bash
# Fix all permissions (automatic)
sudo ./fix-permissions.sh jam

# Check current permissions
ls -lhd backups logs backup-scripts

# Check script executability
ls -lh *.sh

# Test write access
touch logs/test.log && rm logs/test.log

# View permission in detail
stat logs/

# Change ownership recursively
sudo chown -R jam:jam .

# Make script executable
chmod +x script.sh

# Set directory permissions
chmod 755 directory/

# Set file permissions
chmod 644 file.txt
```

---

## Summary

### What to Remember

1. ✅ **Use fix-permissions.sh** for automatic fix
2. ✅ **Run scripts as regular user** (not root)
3. ✅ **Use user crontab** (not root crontab)
4. ✅ **Verify permissions** after deployment
5. ✅ **Protect .env file** with 600 permissions

### Permission Checklist

- [ ] Directories owned by user (not root)
- [ ] Directories have 755 permission
- [ ] Scripts have 755 permission (executable)
- [ ] Regular files have 644 permission
- [ ] .env file has 600 permission
- [ ] User can create files in logs/
- [ ] Cron runs as user (not root)
- [ ] Backups succeed without permission errors

---

**Document Version:** 1.0
**Last Updated:** October 2025
**Status:** ✅ Production Ready
