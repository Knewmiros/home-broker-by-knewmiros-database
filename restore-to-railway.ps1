# Restore backup to Railway PostgreSQL using Docker

Write-Host "=== RESTORE BACKUP TO RAILWAY ===" -ForegroundColor Green
Write-Host ""

# # Step 1: Get DATABASE_URL
# Write-Host "Step 1: Enter your Railway PUBLIC DATABASE_URL" -ForegroundColor Cyan
# Write-Host "(Find it in Railway dashboard > PostgreSQL > Connect)" -ForegroundColor Gray
# Write-Host ""
# $dbUrl = Read-Host "DATABASE_URL"
$dbUrl ="postgresql://postgres:OucZIPSyvBGOUpARieTkeUEEWLFgLaPm@yamanote.proxy.rlwy.net:16559/railway"

if (!$dbUrl -or $dbUrl -eq "") {
    Write-Host "❌ No URL provided!" -ForegroundColor Red
    exit 1
}

if ($dbUrl -match 'railway\.internal') {
    Write-Host "❌ This is an internal URL! Need the PUBLIC one" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: List available backups
Write-Host "Step 2: Available backup files:" -ForegroundColor Cyan
Write-Host ""

if (Test-Path "backups") {
    $backups = Get-ChildItem "backups\*.sql" | Sort-Object LastWriteTime -Descending
    
    if ($backups.Count -eq 0) {
        Write-Host "❌ No backup files found in backups folder!" -ForegroundColor Red
        exit 1
    }
    
    $i = 1
    foreach ($backup in $backups) {
        $size = [math]::Round($backup.Length / 1KB, 2)
        Write-Host "  $i. $($backup.Name) - ${size}KB - $($backup.LastWriteTime)" -ForegroundColor Gray
        $i++
    }
    
    Write-Host ""
    $selection = Read-Host "Select backup number to restore"
    
    if ($selection -lt 1 -or $selection -gt $backups.Count) {
        Write-Host "❌ Invalid selection!" -ForegroundColor Red
        exit 1
    }
    
    $backupFile = $backups[$selection - 1].Name
    $backupPath = "backups\$backupFile"
    
} else {
    Write-Host "Enter backup file path:" -ForegroundColor Yellow
    $backupPath = Read-Host "Path"
    
    if (!(Test-Path $backupPath)) {
        Write-Host "❌ Backup file not found!" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Selected: $backupPath" -ForegroundColor Green
Write-Host ""

# Step 3: Confirm
Write-Host "⚠️  WARNING: This will restore data to Railway database!" -ForegroundColor Yellow
Write-Host "   Existing data may be affected depending on backup type." -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Type 'YES' to continue"

if ($confirm -ne "YES") {
    Write-Host "❌ Restore cancelled" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Restoring backup to Railway..." -ForegroundColor Cyan
Write-Host ""

# Get current directory for Docker volume mount
$currentDir = (Get-Location).Path

# Convert Windows path to Linux path for Docker
$linuxBackupPath = $backupPath -replace '\\', '/'

Write-Host "Backup file: $backupPath" -ForegroundColor Gray
Write-Host ""

# Restore using Docker
docker run --rm `
    -v "${currentDir}:/workspace" `
    -w /workspace `
    postgres:15-alpine `
    psql "$dbUrl" -f "/workspace/$linuxBackupPath"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Backup restored successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Verify
    Write-Host "📊 Verifying tables..." -ForegroundColor Cyan
    docker run --rm postgres:15-alpine psql "$dbUrl" -c "\dt"
    
    Write-Host ""
    Write-Host "=== RESTORE COMPLETE ===" -ForegroundColor Green
    
} else {
    Write-Host ""
    Write-Host "❌ Restore failed!" -ForegroundColor Red
    Write-Host "Check errors above" -ForegroundColor Yellow
    exit 1
}
