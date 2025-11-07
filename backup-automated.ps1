# Automated Backup Script for Production
# Schedule this with Task Scheduler (Windows) or cron (Linux)

param(
    [string]$BackupType = "data",
    [string]$BackupName = "",
    [int]$RetentionDays = 30
)

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = "backups"

if (!(Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir
}

# Generate backup name
if ($BackupName -eq "") {
    $BackupName = "backup_${BackupType}_${timestamp}.sql"
} else {
    $BackupName = "${BackupName}_${timestamp}.sql"
}

$backupPath = Join-Path $backupDir $BackupName

Write-Host "=== AUTOMATED BACKUP ===" -ForegroundColor Green
Write-Host "Time: $(Get-Date)"
Write-Host "Type: $BackupType"
Write-Host "File: $backupPath"

# Perform backup
$containerId = docker compose ps -q postgres
if (!$containerId) {
    Write-Host "❌ Database container not running!" -ForegroundColor Red
    exit 1
}

switch ($BackupType) {
    "complete" {
        docker compose exec postgres pg_dumpall -U postgres > $backupPath
    }
    "schema" {
        docker compose exec postgres pg_dump -U postgres -d broker_db --schema-only > $backupPath
    }
    default {
        docker compose exec postgres pg_dump -U postgres -d broker_db --data-only --inserts > $backupPath
    }
}

if ($LASTEXITCODE -eq 0) {
    $size = (Get-Item $backupPath).Length / 1MB
    Write-Host "✅ Backup completed: $([math]::Round($size, 2)) MB" -ForegroundColor Green
    
    # Compress backup
    if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
        $zipPath = "$backupPath.zip"
        Compress-Archive -Path $backupPath -DestinationPath $zipPath -Force
        Remove-Item $backupPath
        Write-Host "✅ Backup compressed: $zipPath" -ForegroundColor Green
    }
    
    # Clean old backups
    Write-Host "`nCleaning backups older than $RetentionDays days..." -ForegroundColor Yellow
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    $oldBackups = Get-ChildItem $backupDir -Filter "*.sql*" | Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    foreach ($backup in $oldBackups) {
        Remove-Item $backup.FullName -Force
        Write-Host "Deleted: $($backup.Name)" -ForegroundColor Gray
    }
    
    Write-Host "✅ Cleanup complete" -ForegroundColor Green
    
    # Upload to cloud storage (if configured)
    if ($env:BACKUP_S3_BUCKET -or $env:BACKUP_AZURE_CONTAINER -or $env:BACKUP_GCS_BUCKET) {
        Write-Host "`nUploading to cloud storage..." -ForegroundColor Cyan
        
        $uploadFile = if (Test-Path $zipPath) { $zipPath } else { $backupPath }\

        # Google Cloud Storage  
        if ($env:BACKUP_GCS_BUCKET -and (Get-Command gsutil -ErrorAction SilentlyContinue)) {
            Write-Host "Uploading to GCS..." -ForegroundColor Yellow
            gsutil cp $uploadFile "$env:BACKUP_GCS_BUCKET/broker-db/$(Split-Path $uploadFile -Leaf)" 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Uploaded to Google Cloud Storage" -ForegroundColor Green
            }
        }
       
        # AWS S3
        if ($env:BACKUP_S3_BUCKET -and (Get-Command aws -ErrorAction SilentlyContinue)) {
            Write-Host "Uploading to S3..." -ForegroundColor Yellow
            $s3Key = "broker-db-backups/$(Split-Path $uploadFile -Leaf)"
            aws s3 cp $uploadFile "s3://$env:BACKUP_S3_BUCKET/$s3Key" --storage-class STANDARD_IA 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Uploaded to S3: s3://$env:BACKUP_S3_BUCKET/$s3Key" -ForegroundColor Green
            }
        }
        
        # Azure Blob Storage
        if ($env:BACKUP_AZURE_CONTAINER -and (Get-Command az -ErrorAction SilentlyContinue)) {
            Write-Host "Uploading to Azure..." -ForegroundColor Yellow
            az storage blob upload `
                --account-name $env:BACKUP_AZURE_ACCOUNT `
                --container-name $env:BACKUP_AZURE_CONTAINER `
                --name "broker-db/$(Split-Path $uploadFile -Leaf)" `
                --file $uploadFile `
                --tier Cool 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Uploaded to Azure" -ForegroundColor Green
            }
        }
        

    }
    
} else {
    Write-Host "❌ Backup failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== BACKUP COMPLETE ===" -ForegroundColor Green
