How to run the scripts in Powershell

# Set execution policy (one time)

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Navigate to your standalone project

i.e. cd "f:\MyWebApps\sales_rep_form_database"

# DEVELOPMENT ENVIRONMENT

## Start database

.\start.ps1

## Check status

.\status.ps1

## Create backups

.\backup.ps1 # Data backup with timestamp
.\backup.ps1 -BackupName "my_backup" # Custom name
.\backup.ps1 -BackupType "complete" # Complete backup
.\backup.ps1 -BackupType "schema" # Schema only
.\backup.ps1 -BackupType "all" # Full system backup (recommended)

## Connect to database

.\connect.ps1

## Restore from backup

.\restore.ps1 -BackupFile "backup_data_20241106_143022.sql"

## Stop database

.\stop.ps1

---

# PRODUCTION ENVIRONMENT

## Setup (First Time)

1. Copy environment template:

   ```powershell
   Copy-Item .env.example .env
   ```

2. Edit `.env` with strong passwords:

   ```powershell
   notepad .env
   ```

3. Review production checklist:
   ```powershell
   notepad PRODUCTION_CHECKLIST.md
   ```

## Start production database

.\start-prod.ps1

## Check production status

.\status-prod.ps1

## Stop production database

.\stop-prod.ps1

## Production backups

.\backup-automated.ps1 -BackupType "all" -RetentionDays 30

---

# Key Differences: Dev vs Production

| Feature         | Development                     | Production                                     |
| --------------- | ------------------------------- | ---------------------------------------------- |
| Config file     | docker-compose.yaml             | docker-compose.prod.yaml                       |
| Scripts         | start.ps1, stop.ps1, status.ps1 | start-prod.ps1, stop-prod.ps1, status-prod.ps1 |
| Security        | Trust auth, verbose logging     | SSL/TLS, scram-sha-256 auth                    |
| Passwords       | Simple (development only!)      | Strong, from .env                              |
| Resource limits | None                            | CPU/Memory limits                              |
| Restart policy  | unless-stopped                  | always                                         |
| Monitoring      | Basic                           | Health checks + monitoring                     |
