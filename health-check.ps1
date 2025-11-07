# Health Check Script for Production Monitoring

Write-Host "=== DATABASE HEALTH CHECK ===" -ForegroundColor Green
Write-Host "Time: $(Get-Date)" -ForegroundColor Cyan

$issues = @()

# 1. Container Status
Write-Host "`n1. Container Status" -ForegroundColor Yellow
$container = docker compose ps --format json | ConvertFrom-Json | Where-Object { $_.Name -like "*postgres*" }
if ($container -and $container.State -eq "running") {
    Write-Host "   ✅ Container is running" -ForegroundColor Green
} else {
    Write-Host "   ❌ Container is not running!" -ForegroundColor Red
    $issues += "Container not running"
}

# 2. Database Connectivity
Write-Host "`n2. Database Connectivity" -ForegroundColor Yellow
$dbTest = docker compose exec postgres pg_isready -U postgres -d broker_db 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ Database accepting connections" -ForegroundColor Green
} else {
    Write-Host "   ❌ Database not responding!" -ForegroundColor Red
    $issues += "Database not responding"
}

# 3. Disk Space
Write-Host "`n3. Disk Space" -ForegroundColor Yellow
$volumeSize = docker compose exec postgres df -h /var/lib/postgresql/data | Select-String -Pattern "(\d+)%" | ForEach-Object { $_.Matches.Groups[1].Value }
if ($volumeSize) {
    $usage = [int]$volumeSize
    if ($usage -lt 80) {
        Write-Host "   ✅ Disk usage: ${usage}%" -ForegroundColor Green
    } elseif ($usage -lt 90) {
        Write-Host "   ⚠️  Disk usage: ${usage}%" -ForegroundColor Yellow
        $issues += "Disk usage high: ${usage}%"
    } else {
        Write-Host "   ❌ Disk usage: ${usage}% (Critical!)" -ForegroundColor Red
        $issues += "Disk usage critical: ${usage}%"
    }
}

# 4. Connection Count
Write-Host "`n4. Active Connections" -ForegroundColor Yellow
$connections = docker compose exec postgres psql -U postgres -d broker_db -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>$null
if ($connections) {
    Write-Host "   ✅ Active connections: $($connections.Trim())" -ForegroundColor Green
}

# 5. Replication Status (if configured)
Write-Host "`n5. Replication Status" -ForegroundColor Yellow
Write-Host "   ℹ️  Not configured" -ForegroundColor Gray

# 6. Recent Backups
Write-Host "`n6. Backup Status" -ForegroundColor Yellow
if (Test-Path "backups") {
    $latestBackup = Get-ChildItem "backups" -Filter "*.sql*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestBackup) {
        $age = (Get-Date) - $latestBackup.LastWriteTime
        if ($age.TotalHours -lt 24) {
            Write-Host "   ✅ Latest backup: $($latestBackup.Name) ($([math]::Round($age.TotalHours, 1)) hours ago)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Latest backup: $($latestBackup.Name) ($([math]::Round($age.TotalDays, 1)) days ago)" -ForegroundColor Yellow
            $issues += "Backup older than 24 hours"
        }
    } else {
        Write-Host "   ❌ No backups found!" -ForegroundColor Red
        $issues += "No backups available"
    }
}

# 7. Database Size
Write-Host "`n7. Database Size" -ForegroundColor Yellow
$dbSize = docker compose exec postgres psql -U postgres -d broker_db -t -c "SELECT pg_size_pretty(pg_database_size('broker_db'));" 2>$null
if ($dbSize) {
    Write-Host "   ℹ️  Size: $($dbSize.Trim())" -ForegroundColor Cyan
}

# 8. Table Counts
Write-Host "`n8. Data Integrity" -ForegroundColor Yellow
docker compose exec postgres psql -U postgres -d broker_db -c "
SELECT 'organisations' as table_name, COUNT(*) as count FROM organisations 
UNION ALL SELECT 'users', COUNT(*) FROM users 
UNION ALL SELECT 'job_data', COUNT(*) FROM job_data
UNION ALL SELECT 'commissions', COUNT(*) FROM commissions
UNION ALL SELECT 'costing_request', COUNT(*) FROM costing_request
UNION ALL SELECT 'request_content', COUNT(*) FROM request_content
UNION ALL SELECT 'buyer_details', COUNT(*) FROM buyer_details 
UNION ALL SELECT 'uploaded_files', COUNT(*) FROM uploaded_files
UNION ALL SELECT 'builder_submission', COUNT(*) FROM builder_submission;" 2>$null

# Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Green
if ($issues.Count -eq 0) {
    Write-Host "✅ All checks passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Issues found:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "   - $issue" -ForegroundColor Red
    }
    exit 1
}
