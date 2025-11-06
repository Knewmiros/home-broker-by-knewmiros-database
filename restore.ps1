param(
    [Parameter(Mandatory=$true)]
    [string]$BackupFile
)

Write-Host "=== RESTORING DATABASE FROM BACKUP ===" -ForegroundColor Green
Write-Host "Backup file: $BackupFile"

# Check if backup file exists
$fullPath = if (Test-Path $BackupFile) {
    $BackupFile
} elseif (Test-Path "backups\$BackupFile") {
    "backups\$BackupFile"
} elseif (Test-Path "backups\$BackupFile.sql") {
    "backups\$BackupFile.sql"
} else {
    $null
}

if (!$fullPath) {
    Write-Host "❌ Backup file not found: $BackupFile" -ForegroundColor Red
    Write-Host "`nAvailable backups:" -ForegroundColor Yellow
    if (Test-Path "backups") {
        Get-ChildItem "backups" -Filter "*.sql" | Select-Object Name, Length, LastWriteTime | Format-Table
    } else {
        Write-Host "No backups directory found"
    }
    exit 1
}

# Check if database is running
$containerRunning = docker compose ps --format json | ConvertFrom-Json | Where-Object { $_.State -eq "running" }
if (!$containerRunning) {
    Write-Host "❌ Database is not running. Starting it first..." -ForegroundColor Red
    .\start.ps1
    Start-Sleep -Seconds 5
}

Write-Host "Copying backup file to container..." -ForegroundColor Yellow
$containerId = docker compose ps -q postgres
if (!$containerId) {
    Write-Host "❌ Could not find postgres container" -ForegroundColor Red
    exit 1
}
docker cp $fullPath ${containerId}:/tmp/restore.sql

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to copy backup file to container" -ForegroundColor Red
    exit 1
}

Write-Host "Restoring database..." -ForegroundColor Yellow
docker compose exec postgres psql -U postgres -d broker_db -f /tmp/restore.sql

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Restore completed successfully!" -ForegroundColor Green
    
    # Show data counts after restore
    Write-Host "`n📊 Data after restore:" -ForegroundColor Cyan
    docker compose exec postgres psql -U postgres -d broker_db -c "
    SELECT 'organisations' as table_name, COUNT(*) as count FROM organisations 
    UNION ALL SELECT 'users', COUNT(*) FROM users 
    UNION ALL SELECT 'job_data', COUNT(*) FROM job_data;"
    
} else {
    Write-Host "❌ Restore failed" -ForegroundColor Red
}

# Clean up
docker compose exec postgres rm -f /tmp/restore.sql

Write-Host "`n=== RESTORE COMPLETE ===" -ForegroundColor Green