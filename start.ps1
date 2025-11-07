Write-Host "=== STARTING STANDALONE BROKER DATABASE ===" -ForegroundColor Green
# Write-Host "Database: broker_db"
# Write-Host "User: postgres"
# Write-Host "Password: password"
# Write-Host "Port: 5432"
# Write-Host ""

# Start the database
Write-Host "Starting PostgreSQL container..." -ForegroundColor Yellow
docker compose up -d

# Wait for startup
Write-Host "Waiting for database to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Check health
Write-Host "Checking database health..." -ForegroundColor Yellow
$health = docker compose exec postgres pg_isready -U postgres -d broker_db 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Database is ready!" -ForegroundColor Green
    
    # Show data counts
    Write-Host "`n📊 Current data:" -ForegroundColor Cyan
    docker compose exec postgres psql -U postgres -d broker_db -c "
    SELECT 'organisations' as table_name, COUNT(*) as count FROM organisations 
    UNION ALL SELECT 'users', COUNT(*) FROM users 
    UNION ALL SELECT 'job_data', COUNT(*) FROM job_data
    UNION ALL SELECT 'commissions', COUNT(*) FROM commissions
    UNION ALL SELECT 'costing_request', COUNT(*) FROM costing_request
    UNION ALL SELECT 'request_content', COUNT(*) FROM request_content
    UNION ALL SELECT 'buyer_details', COUNT(*) FROM buyer_details 
    UNION ALL SELECT 'uploaded_files', COUNT(*) FROM uploaded_files
    UNION ALL SELECT 'builder_submission', COUNT(*) FROM builder_submission;"
    
    Write-Host "`n🔗 Connection info:" -ForegroundColor Cyan
    # Load .env file
    $envVars = @{}
    if (Test-Path ".env") {
        Get-Content ".env" | ForEach-Object {
            if ($_ -match '^([^=]+)=(.+)$') {
                $envVars[$matches[1]] = $matches[2]
            }
        }
    }
    Write-Host "   Host: localhost"
    Write-Host "   Port: $($envVars['PORT'] -replace ':.*','')"
    Write-Host "   Database: $($envVars['POSTGRES_DB'])"
    Write-Host ""
    Write-Host "👤 Database Users:" -ForegroundColor Cyan
    Write-Host "   Admin User: $($envVars['POSTGRES_USER']) (for admin tasks)"
    Write-Host "   App User: broker_app (for application connections)"
    Write-Host ""
    Write-Host "📝 Connect using:" -ForegroundColor Cyan
    Write-Host "   Admin: docker compose exec postgres psql -U postgres -d broker_db"
    Write-Host "   App:   docker compose exec postgres psql -U broker_app -d broker_db"
    Write-Host "   Or run: .\connect.ps1"
    
} else {
    Write-Host "❌ Database failed to start" -ForegroundColor Red
    Write-Host "Checking logs..." -ForegroundColor Yellow
    docker compose logs postgres
}

Write-Host "`n=== STARTUP COMPLETE ===" -ForegroundColor Green