How to run the scripts in Powershell

# Set execution policy (one time)

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Navigate to your standalone project

i.e. cd "f:\MyWebApps\standalone-broker-db"

# Start database

.\start.ps1

# Check status

.\status.ps1

# Create backups

.\backup.ps1 # Data backup with timestamp
.\backup.ps1 -BackupName "my_backup" # Custom name
.\backup.ps1 -BackupType "complete" # Complete backup
.\backup.ps1 -BackupType "schema" # Schema only

# Connect to database

.\connect.ps1

# Restore from backup

.\restore.ps1 -BackupFile "backup_data_20241106_143022.sql (name of backup file) "

# Stop database

.\stop.ps1
