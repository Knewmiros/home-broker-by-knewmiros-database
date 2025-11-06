Write-Host "=== CONNECTING TO BROKER DATABASE ===" -ForegroundColor Green

# Check if database is running
$containerRunning = docker compose ps --format json | ConvertFrom-Json | Where-Object { $_.State -eq "running" }
if (!$containerRunning) {
    Write-Host "❌ Database is not running. Starting it first..." -ForegroundColor Red
    .\start.ps1
    Write-Host "`nPress any key to continue to connection..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

Write-Host "Opening PostgreSQL console..." -ForegroundColor Yellow
Write-Host "Database: broker_db" -ForegroundColor Cyan
Write-Host "Type '\q' to exit" -ForegroundColor Cyan
Write-Host "Type '\dt' to list tables" -ForegroundColor Cyan
Write-Host "Type '\d tablename' to describe a table" -ForegroundColor Cyan
Write-Host ""

# Connect to database
docker compose exec postgres psql -U postgres -d broker_db
