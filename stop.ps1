Write-Host "=== STOPPING STANDALONE BROKER DATABASE ===" -ForegroundColor Yellow

# Show current status
Write-Host "Current container status:" -ForegroundColor Cyan
docker compose ps

# Stop the database
Write-Host "`nStopping PostgreSQL container..." -ForegroundColor Yellow
docker compose down

Write-Host "✅ Database stopped" -ForegroundColor Green
Write-Host "Volume data is preserved for next startup" -ForegroundColor Cyan