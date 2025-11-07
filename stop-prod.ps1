Write-Host "=== STOPPING PRODUCTION BROKER DATABASE ===" -ForegroundColor Yellow

# Confirm before stopping production
$confirm = Read-Host "Are you sure you want to stop the PRODUCTION database? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Cancelled" -ForegroundColor Gray
    exit 0
}

Write-Host "Stopping PostgreSQL container..." -ForegroundColor Yellow
docker compose -f docker-compose.prod.yaml down

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Production database stopped" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to stop database" -ForegroundColor Red
}

Write-Host "`n=== PRODUCTION DATABASE STOPPED ===" -ForegroundColor Yellow
