# Simple Railway Deployment Script
# Deploys schema and creates app user

Write-Host "=== RAILWAY DEPLOYMENT ===" -ForegroundColor Green
Write-Host ""

# Step 1: Get the PUBLIC DATABASE_URL
# Write-Host "Step 1: Enter your Railway PUBLIC DATABASE_URL" -ForegroundColor Cyan
# Write-Host "Find it in Railway > PostgreSQL > Connect tab" -ForegroundColor Gray
# Write-Host "Example: postgresql://postgres:pass@containers-us-west-123.railway.app:5432/railway" -ForegroundColor Gray
# Write-Host ""
$dbUrl ="postgresql://postgres:rxBJzGsDCVvjBnNtytHcHPuPnbtOOXvZ@turntable.proxy.rlwy.net:48854/railway"

if (!$dbUrl -or $dbUrl -eq "") {
    Write-Host "❌ No URL provided!" -ForegroundColor Red
    exit 1
}

if ($dbUrl -match 'railway\.internal') {
    Write-Host "❌ This is an internal URL! Need the PUBLIC one with 'containers-' hostname" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Deploying schema.sql..." -ForegroundColor Cyan

# Deploy schema using Docker
$currentDir = (Get-Location).Path

docker run --rm `
    -v "${currentDir}:/workspace" `
    -w /workspace `
    postgres:15-alpine `
    psql "$dbUrl" -f schema.sql

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Schema deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Schema deployed!" -ForegroundColor Green
Write-Host ""

# Step 3: Create broker_app user
Write-Host "Step 3: Creating broker_app user..." -ForegroundColor Cyan

# Get password from .env
$appPassword = ""
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^BROKER_APP_PASSWORD=(.+)$') {
            $appPassword = $matches[1]
        }
    }
}

if (!$appPassword) {
    $appPassword = Read-Host "Enter password for broker_app user"
}

# Create SQL file for user
$userSql = @"
DO `$`$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'broker_app') THEN
        CREATE USER broker_app WITH PASSWORD '$appPassword';
    END IF;
END `$`$;

GRANT CONNECT ON DATABASE railway TO broker_app;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO broker_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO broker_app;
GRANT ALL PRIVILEGES ON SCHEMA public TO broker_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO broker_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO broker_app;
"@

$userSql | Out-File -FilePath "temp_user.sql" -Encoding UTF8 -NoNewline

# Execute user creation
docker run --rm `
    -v "${currentDir}:/workspace" `
    -w /workspace `
    postgres:15-alpine `
    psql "$dbUrl" -f temp_user.sql

Remove-Item "temp_user.sql" -Force -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ User creation failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ broker_app user created!" -ForegroundColor Green
Write-Host ""

# Step 4: Verify
Write-Host "Step 4: Verifying deployment..." -ForegroundColor Cyan

docker run --rm postgres:15-alpine psql "$dbUrl" -c "\dt"

Write-Host ""
Write-Host "=== DEPLOYMENT COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Host "Your database is ready!" -ForegroundColor Cyan
Write-Host "Connection info for your backend:" -ForegroundColor Gray
Write-Host "  User: broker_app" -ForegroundColor Gray
Write-Host "  Password: $appPassword" -ForegroundColor Gray
Write-Host "  Database: railway" -ForegroundColor Gray
