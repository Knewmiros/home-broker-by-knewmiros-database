# Add column to Railway database

Write-Host "=== ADD COLUMN TO RAILWAY DATABASE ===" -ForegroundColor Green
Write-Host ""

# Database URL (update if needed)
$dbUrl = "postgresql://postgres:OucZIPSyvBGOUpARieTkeUEEWLFgLaPm@yamanote.proxy.rlwy.net:16559/railway"

Write-Host "Enter your SQL ALTER TABLE command:" -ForegroundColor Cyan
Write-Host "Example: ALTER TABLE job_data ADD COLUMN new_column VARCHAR(255);" -ForegroundColor Gray
Write-Host ""
$sql = Read-Host "SQL"

if (!$sql) {
    Write-Host "❌ No SQL provided!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Executing SQL on Railway..." -ForegroundColor Yellow

docker run --rm postgres:15-alpine psql "$dbUrl" -c "$sql"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Column added successfully!" -ForegroundColor Green
    
    # Show table structure
    Write-Host ""
    Write-Host "📊 Updated table structure:" -ForegroundColor Cyan
    
    # Extract table name from SQL
    if ($sql -match 'ALTER TABLE (\w+)') {
        $tableName = $matches[1]
        docker run --rm postgres:15-alpine psql "$dbUrl" -c "\d $tableName"
    }
} else {
    Write-Host ""
    Write-Host "❌ Failed to add column!" -ForegroundColor Red
}
