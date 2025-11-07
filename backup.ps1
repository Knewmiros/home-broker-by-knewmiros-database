param(
    [string]$BackupName = "",
    [string]$BackupType = "data"
)

# Generate backup name if not provided
if ($BackupName -eq "") {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $BackupName = "backup_$BackupType`_$timestamp"
}

Write-Host "=== CREATING BACKUP ===" -ForegroundColor Green
Write-Host "Backup name: $BackupName"
Write-Host "Backup type: $BackupType"

# Ensure backups directory exists
if (!(Test-Path "backups")) {
    New-Item -ItemType Directory -Path "backups"
    Write-Host "Created backups directory" -ForegroundColor Yellow
}

# Check if database is running
$containerRunning = docker compose ps --format json | ConvertFrom-Json | Where-Object { $_.State -eq "running" }
if (!$containerRunning) {
    Write-Host "❌ Database is not running. Starting it first..." -ForegroundColor Red
    docker compose up -d
    Start-Sleep -Seconds 10
}

# Create backup based on type
switch ($BackupType) {
    "data" {
        Write-Host "Creating data-only backup..." -ForegroundColor Yellow
        docker compose exec postgres pg_dump -U postgres -d broker_db --data-only --inserts > "backups\$BackupName.sql"
    }
    "complete" {
        Write-Host "Creating complete backup (structure + data)..." -ForegroundColor Yellow
        docker compose exec postgres pg_dump -U postgres -d broker_db > "backups\$BackupName.sql"
    }
    "schema" {
        Write-Host "Creating schema-only backup..." -ForegroundColor Yellow
        docker compose exec postgres pg_dump -U postgres -d broker_db --schema-only > "backups\$BackupName.sql"
    }
    "all" {
        Write-Host "Creating FULL system backup (all databases + users + roles)..." -ForegroundColor Yellow
        docker compose exec postgres pg_dumpall -U postgres > "backups\$BackupName.sql"
    }
    default {
        Write-Host "❌ Invalid backup type. Use: data, complete, schema, or all" -ForegroundColor Red
        exit 1
    }
}

# Verify backup was created
$backupFile = "backups\$BackupName.sql"
if (Test-Path $backupFile) {
    $size = (Get-Item $backupFile).Length
    Write-Host "✅ Backup created: $backupFile" -ForegroundColor Green
    Write-Host "📏 Size: $([math]::Round($size/1KB, 2)) KB"
    
    # Show what was backed up
    if ($BackupType -eq "data" -or $BackupType -eq "complete") {
        $insertCount = (Get-Content $backupFile | Select-String "INSERT INTO").Count
        Write-Host "📝 INSERT statements: $insertCount"
        
        # Count by table
        Write-Host "`n📋 Data backed up:" -ForegroundColor Cyan
        $tableInserts = Get-Content $backupFile | Select-String "INSERT INTO public\." | ForEach-Object { 
            ($_ -split "INSERT INTO public\.")[1] -split " " | Select-Object -First 1 
        } | Group-Object | Sort-Object Name
        
        foreach ($table in $tableInserts) {
            Write-Host "   - $($table.Name): $($table.Count) rows"
        }
    }
} else {
    Write-Host "❌ Backup failed" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== BACKUP COMPLETE ===" -ForegroundColor Green