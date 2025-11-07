# Backup and Restore Procedures

## Table of Contents

- [Backup Strategy](#backup-strategy)
- [Automated Backups](#automated-backups)
- [Manual Backups](#manual-backups)
- [Cloud Storage](#cloud-storage)
- [Testing Backups](#testing-backups)
- [Restoration Procedures](#restoration-procedures)
- [Troubleshooting](#troubleshooting)

---

## Backup Strategy

### Backup Types

| Type             | Command                             | Use Case              | Size   | Restore Time |
| ---------------- | ----------------------------------- | --------------------- | ------ | ------------ |
| **Data Only**    | `.\backup.ps1`                      | Quick daily snapshots | Small  | Fast         |
| **Complete**     | `.\backup.ps1 -BackupType complete` | Full database         | Medium | Medium       |
| **All (System)** | `.\backup.ps1 -BackupType all`      | Everything inc. users | Large  | Slow         |
| **Schema**       | `.\backup.ps1 -BackupType schema`   | Structure only        | Tiny   | Fast         |

### Recommended Schedule

- **Daily**: Full system backup (2:00 AM)
- **Hourly**: Data-only (business hours only)
- **Pre-deployment**: Complete backup before any changes
- **Monthly**: Archive to cold storage

### Retention Policy

- **Local backups**: 30 days
- **Cloud storage**: 90 days (standard)
- **Archived backups**: 1 year (cold storage)

---

## Automated Backups

### Initial Setup

```powershell
# Run once to configure automatic backups
.\setup-automated-backups.ps1
```

This creates a Windows Task Scheduler task that:

- Runs daily at 2:00 AM
- Creates full system backup
- Compresses the backup
- Deletes backups older than 30 days
- Uploads to cloud storage (if configured)

### Verify Automated Backup

```powershell
# Check if task exists
Get-ScheduledTask -TaskName "BrokerDB-DailyBackup"

# View task history
Get-ScheduledTaskInfo -TaskName "BrokerDB-DailyBackup"

# Run task manually (for testing)
Start-ScheduledTask -TaskName "BrokerDB-DailyBackup"
```

### Modify Schedule

```powershell
# Open Task Scheduler GUI
taskschd.msc

# Navigate to: Task Scheduler Library > BrokerDB-DailyBackup
# Modify triggers, actions, etc.
```

---

## Manual Backups

### Quick Backup (Development)

```powershell
# Data only (fastest)
.\backup.ps1

# With custom name
.\backup.ps1 -BackupName "before_migration"
```

### Production Backup

```powershell
# Full system backup (recommended)
.\backup.ps1 -BackupType all

# Complete database (structure + data)
.\backup.ps1 -BackupType complete
```

### Pre-Deployment Backup

```powershell
# Always backup before deploying changes!
.\backup.ps1 -BackupType all -BackupName "pre_deploy_v2.0"
```

---

## Cloud Storage

### Setup Cloud Backup

#### AWS S3

```powershell
# 1. Install AWS CLI
choco install awscli

# 2. Configure credentials
aws configure
# AWS Access Key ID: YOUR_KEY
# AWS Secret Access Key: YOUR_SECRET
# Default region: us-east-1
# Default output format: json

# 3. Create S3 bucket
aws s3 mb s3://my-broker-db-backups

# 4. Add to .env file
BACKUP_S3_BUCKET=my-broker-db-backups

# 5. Test upload
.\upload-backup-cloud.ps1 -Provider s3
```

#### Azure Blob Storage

```powershell
# 1. Install Azure CLI
choco install azure-cli

# 2. Login
az login

# 3. Create storage account and container
az storage account create --name mybrokerbackups --resource-group mygroup
az storage container create --name db-backups --account-name mybrokerbackups

# 4. Add to .env
BACKUP_AZURE_ACCOUNT=mybrokerbackups
BACKUP_AZURE_CONTAINER=db-backups

# 5. Test upload
.\upload-backup-cloud.ps1 -Provider azure
```

#### Google Cloud Storage

```powershell
# 1. Install Google Cloud SDK
# Download from: https://cloud.google.com/sdk/docs/install

# 2. Authenticate
gcloud auth login

# 3. Create bucket
gsutil mb gs://my-broker-db-backups

# 4. Add to .env
BACKUP_GCS_BUCKET=gs://my-broker-db-backups

# 5. Test upload
.\upload-backup-cloud.ps1 -Provider gcs
```

### Manual Cloud Upload

```powershell
# Upload latest backup
.\upload-backup-cloud.ps1

# Upload specific backup
.\upload-backup-cloud.ps1 -Provider s3 -BackupFile "backups\backup_all_20251107.sql.zip"
```

---

## Testing Backups

### Why Test Backups?

**Untested backups are useless!** Always verify backups can be restored.

### Test Restoration (Safe Method)

```powershell
# Creates a separate test container to verify backup
.\test-backup-restore.ps1

# Follow prompts to:
# 1. Select a backup
# 2. Choose "Test in NEW container"
# 3. Verify data integrity
# 4. Clean up test container
```

### Quick Verification

```powershell
# Check backup file size (should not be 0 bytes)
Get-ChildItem backups -Filter "*.sql*" | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Check backup contents
Get-Content "backups\latest_backup.sql" | Select-Object -First 50
```

### Monthly Testing Procedure

1. Run `.\test-backup-restore.ps1`
2. Select latest full backup
3. Verify all tables have correct row counts
4. Document test results
5. If test fails, investigate immediately!

---

## Restoration Procedures

### Development Environment Restore

```powershell
# 1. Stop database
.\stop.ps1

# 2. Remove volume (fresh start)
docker volume rm standalone_broker_pgdata

# 3. Start database
.\start.ps1

# 4. Restore backup
.\restore.ps1 -BackupFile "backup_all_20251107.sql"

# 5. Verify restoration
.\status.ps1
```

### Production Environment Restore

```powershell
# ⚠️ CRITICAL: Only in emergency!

# 1. Create immediate backup of current state (even if corrupted)
.\backup.ps1 -BackupType all -BackupName "emergency_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# 2. Stop production database
.\stop-prod.ps1

# 3. Restore from backup
.\restore.ps1 -BackupFile "backups\last_known_good.sql"

# 4. Verify restoration
docker compose -f docker-compose.prod.yaml exec postgres psql -U postgres -d broker_db -c "SELECT COUNT(*) FROM users;"

# 5. Start production
.\start-prod.ps1

# 6. Notify team and verify application functionality
```

### Point-in-Time Recovery (If WAL Enabled)

```powershell
# If you've enabled WAL archiving (advanced)
# Contact DBA or see PostgreSQL PITR documentation
```

---

## Troubleshooting

### Backup Failures

**Problem**: Backup file is 0 bytes

```powershell
# Check if database is running
docker compose ps

# Check Docker logs
docker compose logs postgres
```

**Problem**: "Container not found"

```powershell
# Start database first
.\start.ps1
```

**Problem**: Out of disk space

```powershell
# Check disk usage
Get-PSDrive

# Clean old backups manually
Get-ChildItem backups -Filter "*.sql*" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item
```

### Restoration Failures

**Problem**: "Role does not exist"

```powershell
# Use full system backup (includes roles)
.\backup.ps1 -BackupType all
```

**Problem**: "Database already exists"

```powershell
# Drop and recreate database
docker compose exec postgres psql -U postgres -c "DROP DATABASE broker_db;"
docker compose exec postgres psql -U postgres -c "CREATE DATABASE broker_db;"
```

**Problem**: Permission denied

```powershell
# Ensure you're running PowerShell as Administrator
# Or check file permissions
icacls backups\backup.sql
```

### Cloud Upload Failures

**Problem**: AWS credentials not found

```powershell
aws configure list
aws configure
```

**Problem**: Azure authentication expired

```powershell
az login
```

**Problem**: Network timeout

```powershell
# Compress backup first to reduce upload time
Compress-Archive -Path backups\backup.sql -DestinationPath backups\backup.zip
```

---

## Quick Reference

### Daily Operations

```powershell
# Check backup status
Get-ChildItem backups | Sort-Object LastWriteTime -Descending | Select-Object -First 1

# Manual backup
.\backup.ps1 -BackupType all

# Test latest backup
.\test-backup-restore.ps1

# Upload to cloud
.\upload-backup-cloud.ps1
```

### Emergency Contacts

- **DBA**: [Your contact info]
- **DevOps**: [Your contact info]
- **Cloud Support**: [Provider support numbers]

---

## Backup Checklist

### Daily

- [ ] Verify automated backup completed
- [ ] Check backup file size is reasonable
- [ ] Verify cloud upload succeeded (if configured)

### Weekly

- [ ] Review backup logs
- [ ] Check available disk space
- [ ] Verify retention policy is working

### Monthly

- [ ] Test backup restoration
- [ ] Review and update this documentation
- [ ] Audit backup access logs
- [ ] Archive old backups to cold storage

### Quarterly

- [ ] Full disaster recovery drill
- [ ] Review backup strategy
- [ ] Update cloud storage lifecycle policies
- [ ] Security audit of backup files

---

**Last Updated**: November 7, 2025
**Document Owner**: Database Administrator
**Review Frequency**: Monthly
