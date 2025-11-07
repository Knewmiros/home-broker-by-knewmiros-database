Write-Host "=== STARTING PRODUCTION BROKER DATABASE ===" -ForegroundColor Green
Write-Host "⚠️  PRODUCTION MODE" -ForegroundColor Yellow
Write-Host ""

# Load environment variables
if (!(Test-Path ".env")) {
    Write-Host "❌ .env file not found!" -ForegroundColor Red
    Write-Host "Copy .env.example to .env and configure it first" -ForegroundColor Yellow
    exit 1
}

# Verify production settings
Write-Host "Checking production configuration..." -ForegroundColor Yellow
$envContent = Get-Content ".env" -Raw
if ($envContent -match "CHANGE_ME" -or $envContent -match "defaultpassword") {
    Write-Host "❌ WARNING: Default passwords detected in .env!" -ForegroundColor Red
    Write-Host "Please update all passwords before running in production" -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (yes/no)"
    if ($continue -ne "yes") {
        exit 1
    }
}

# Start the database
Write-Host "Starting PostgreSQL container (PRODUCTION)..." -ForegroundColor Yellow
docker compose -f docker-compose.prod.yaml up -d

# Wait for startup
Write-Host "Waiting for database to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Check health
Write-Host "Checking database health..." -ForegroundColor Yellow
$health = docker compose -f docker-compose.prod.yaml exec postgres pg_isready -U postgres -d broker_db 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Production database is ready!" -ForegroundColor Green
    
    # Show connection info (from .env)
    $envVars = @{}
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.+)$') {
            $envVars[$matches[1]] = $matches[2]
        }
    }
    
    Write-Host "`n🔗 Connection Info:" -ForegroundColor Cyan
    Write-Host "   Host: localhost (internal: standalone_broker_postgres)"
    Write-Host "   Port: $($envVars['PORT'] -replace ':.*','')"
    Write-Host "   Database: $($envVars['POSTGRES_DB'])"
    Write-Host "   Admin User: $($envVars['POSTGRES_USER'])"
    Write-Host "   App User: broker_app"
    
    Write-Host "`n⚠️  SECURITY REMINDERS:" -ForegroundColor Yellow
    Write-Host "   - Use broker_app user for application connections"
    Write-Host "   - Keep postgres user for admin tasks only"
    Write-Host "   - Ensure SSL is configured for remote connections"
    Write-Host "   - Regular backups are scheduled"
    
} else {
    Write-Host "❌ Database is not responding" -ForegroundColor Red
    Write-Host "Check logs: docker compose -f docker-compose.prod.yaml logs" -ForegroundColor Yellow
}

Write-Host "`n=== PRODUCTION DATABASE STARTED ===" -ForegroundColor Green
