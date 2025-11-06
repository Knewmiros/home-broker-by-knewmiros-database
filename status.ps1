Write-Host "=== STANDALONE BROKER DATABASE STATUS ===" -ForegroundColor Green

# Container status
Write-Host "`n🐳 Container Status:" -ForegroundColor Cyan
docker compose ps

# Volume status
Write-Host "`n💾 Volume Status:" -ForegroundColor Cyan
docker volume ls | Select-String "standalone_broker_pgdata"

# Database connection test
$containerRunning = docker compose ps --format json | ConvertFrom-Json | Where-Object { $_.State -eq "running" }
if ($containerRunning) {
    Write-Host "`n📊 Database Status:" -ForegroundColor Cyan
    $dbTest = docker compose exec postgres pg_isready -U postgres -d broker_db 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Database is ready and accepting connections" -ForegroundColor Green
        
        # Show data counts
        Write-Host "`n📋 Current Data:" -ForegroundColor Cyan
        docker compose exec postgres psql -U postgres -d broker_db -c "
        SELECT 'organisations' as table_name, COUNT(*) as count FROM organisations 
        UNION ALL SELECT 'users', COUNT(*) FROM users 
        UNION ALL SELECT 'job_data', COUNT(*) FROM job_data
        UNION ALL SELECT 'commissions', COUNT(*) FROM commissions;"
        
        # Show recent backups
        Write-Host "`n💾 Recent Backups:" -ForegroundColor Cyan
        if (Test-Path "backups") {
            Get-ChildItem "backups" -Filter "*.sql" | Sort-Object LastWriteTime -Descending | Select-Object -First 5 | Select-Object Name, @{Name="Size(KB)";Expression={[math]::Round($_.Length/1KB, 2)}}, LastWriteTime | Format-Table
        } else {
            Write-Host "No backups found"
        }
        
    } else {
        Write-Host "❌ Database is not responding" -ForegroundColor Red
    }
} else {
    Write-Host "`n❌ Database container is not running" -ForegroundColor Red
    Write-Host "Run .\start.ps1 to start the database" -ForegroundColor Yellow
}

Write-Host "`n🔗 Connection Info:" -ForegroundColor Cyan
Write-Host "   Host: localhost"
Write-Host "   Port: 5432"
Write-Host "   Database: broker_db"
Write-Host "   Username: postgres"
Write-Host "   Password: password"

Write-Host "`n=== STATUS COMPLETE ===" -ForegroundColor Green