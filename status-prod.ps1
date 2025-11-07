Write-Host "=== PRODUCTION DATABASE STATUS ===" -ForegroundColor Green
Write-Host "⚠️  PRODUCTION ENVIRONMENT" -ForegroundColor Yellow

# Container status
Write-Host "`n🐳 Container Status:" -ForegroundColor Cyan
docker compose -f docker-compose.prod.yaml ps

# Volume status
Write-Host "`n💾 Volume Status:" -ForegroundColor Cyan
docker volume ls | Select-String "standalone_broker_pgdata"

# Database connection test
$containerRunning = docker compose -f docker-compose.prod.yaml ps --format json | ConvertFrom-Json | Where-Object { $_.State -eq "running" }
if ($containerRunning) {
    Write-Host "`n📊 Database Status:" -ForegroundColor Cyan
    $dbTest = docker compose -f docker-compose.prod.yaml exec postgres pg_isready -U postgres -d broker_db 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Database is ready and accepting connections" -ForegroundColor Green
        
        # Show data counts
        Write-Host "`n📋 Current Data:" -ForegroundColor Cyan
        docker compose -f docker-compose.prod.yaml exec postgres psql -U postgres -d broker_db -c "
        SELECT 'organisations' as table_name, COUNT(*) as count FROM organisations 
        UNION ALL SELECT 'users', COUNT(*) FROM users 
        UNION ALL SELECT 'job_data', COUNT(*) FROM job_data
        UNION ALL SELECT 'commissions', COUNT(*) FROM commissions
        UNION ALL SELECT 'costing_request', COUNT(*) FROM costing_request
        UNION ALL SELECT 'request_content', COUNT(*) FROM request_content
        UNION ALL SELECT 'buyer_details', COUNT(*) FROM buyer_details 
        UNION ALL SELECT 'uploaded_files', COUNT(*) FROM uploaded_files
        UNION ALL SELECT 'builder_submission', COUNT(*) FROM builder_submission;"
        
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
    Write-Host "`n❌ Production database container is not running" -ForegroundColor Red
    Write-Host "Run .\start-prod.ps1 to start the production database" -ForegroundColor Yellow
}

# Load and display connection info
if (Test-Path ".env") {
    $envVars = @{}
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.+)$') {
            $envVars[$matches[1]] = $matches[2]
        }
    }
    
    Write-Host "`n🔗 Connection Info:" -ForegroundColor Cyan
    Write-Host "   Host: localhost"
    Write-Host "   Port: $($envVars['PORT'] -replace ':.*','')"
    Write-Host "   Database: $($envVars['POSTGRES_DB'])"
    Write-Host "   Admin User: $($envVars['POSTGRES_USER'])"
    Write-Host "   App User: broker_app"
}

Write-Host "`n=== STATUS COMPLETE ===" -ForegroundColor Green
