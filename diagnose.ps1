# Comprehensive database diagnostic script
Write-Host "=== DATABASE DIAGNOSTICS ===" -ForegroundColor Green
Write-Host ""

# 1. Check Docker is running
Write-Host "1. Checking Docker..." -ForegroundColor Cyan
$dockerRunning = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
if ($dockerRunning) {
    Write-Host "   ✅ Docker Desktop is running" -ForegroundColor Green
} else {
    Write-Host "   ❌ Docker Desktop is not running!" -ForegroundColor Red
    Write-Host "   Start Docker Desktop first" -ForegroundColor Yellow
    exit 1
}

# 2. Check container status
Write-Host ""
Write-Host "2. Container Status:" -ForegroundColor Cyan
docker compose ps

# 3. Check if port is available
Write-Host ""
Write-Host "3. Checking port 5432..." -ForegroundColor Cyan
$portCheck = Get-NetTCPConnection -LocalPort 5432 -ErrorAction SilentlyContinue
if ($portCheck) {
    Write-Host "   ⚠️  Port 5432 is in use by:" -ForegroundColor Yellow
    $portCheck | Select-Object OwningProcess, State | Format-Table
    
    # Try to identify the process
    $process = Get-Process -Id $portCheck[0].OwningProcess -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "   Process: $($process.ProcessName) (PID: $($process.Id))" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ✅ Port 5432 is available" -ForegroundColor Green
}

# 4. Check volume
Write-Host ""
Write-Host "4. Checking Docker volume..." -ForegroundColor Cyan
$volume = docker volume ls | Select-String "standalone_broker_pgdata"
if ($volume) {
    Write-Host "   ✅ Volume exists: standalone_broker_pgdata" -ForegroundColor Green
    docker volume inspect standalone_broker_pgdata | ConvertFrom-Json | Select-Object Name, Driver, Mountpoint
} else {
    Write-Host "   ⚠️  Volume does not exist (will be created on first start)" -ForegroundColor Yellow
}

# 5. Check .env file
Write-Host ""
Write-Host "5. Checking .env file..." -ForegroundColor Cyan
if (Test-Path ".env") {
    Write-Host "   ✅ .env file exists" -ForegroundColor Green
    
    $envVars = @{}
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.+)$') {
            $key = $matches[1]
            $value = $matches[2]
            $envVars[$key] = $value
            
            # Check for problematic values
            if ($value -match '\$' -and $value -notmatch '\$\$') {
                Write-Host "   ⚠️  Warning: $key contains unescaped $ character" -ForegroundColor Yellow
            }
        }
    }
    
    # Check required variables
    $required = @('POSTGRES_USER', 'POSTGRES_PASSWORD', 'POSTGRES_DB', 'PORT')
    foreach ($var in $required) {
        if ($envVars[$var]) {
            Write-Host "   ✅ $var is set" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $var is missing!" -ForegroundColor Red
        }
    }
} else {
    Write-Host "   ❌ .env file not found!" -ForegroundColor Red
}

# 6. Check docker-compose.yaml
Write-Host ""
Write-Host "6. Checking docker-compose.yaml..." -ForegroundColor Cyan
if (Test-Path "docker-compose.yaml") {
    Write-Host "   ✅ docker-compose.yaml exists" -ForegroundColor Green
    
    # Validate syntax
    $validateResult = docker compose config 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ docker-compose.yaml syntax is valid" -ForegroundColor Green
    } else {
        Write-Host "   ❌ docker-compose.yaml has syntax errors:" -ForegroundColor Red
        Write-Host $validateResult -ForegroundColor Red
    }
} else {
    Write-Host "   ❌ docker-compose.yaml not found!" -ForegroundColor Red
}

# 7. Check init scripts
Write-Host ""
Write-Host "7. Checking init scripts..." -ForegroundColor Cyan
if (Test-Path "schema.sql") {
    Write-Host "   ✅ schema.sql exists" -ForegroundColor Green
} else {
    Write-Host "   ❌ schema.sql not found!" -ForegroundColor Red
}

if (Test-Path "scripts/02-create-app-user.sh") {
    Write-Host "   ✅ 02-create-app-user.sh exists" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  02-create-app-user.sh not found" -ForegroundColor Yellow
}

# 8. View recent logs
Write-Host ""
Write-Host "8. Recent Container Logs (last 30 lines):" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────" -ForegroundColor Gray
docker compose logs --tail 30 postgres 2>&1

# 9. Check for errors in logs
Write-Host ""
Write-Host "9. Searching for errors in logs..." -ForegroundColor Cyan
$errors = docker compose logs postgres 2>&1 | Select-String -Pattern "error|failed|fatal" -CaseSensitive:$false
if ($errors) {
    Write-Host "   ⚠️  Found errors:" -ForegroundColor Yellow
    $errors | Select-Object -First 5 | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Red
    }
} else {
    Write-Host "   ✅ No obvious errors found in logs" -ForegroundColor Green
}

# 10. Summary and recommendations
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Green
Write-Host ""

$containerState = docker compose ps --format json | ConvertFrom-Json | Where-Object { $_.Name -like "*postgres*" }
if ($containerState -and $containerState.State -eq "running") {
    Write-Host "✅ Database appears to be running" -ForegroundColor Green
    Write-Host ""
    Write-Host "Test connection:" -ForegroundColor Cyan
    Write-Host "   docker compose exec postgres pg_isready -U postgres" -ForegroundColor Gray
} else {
    Write-Host "❌ Database is not running properly" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "   1. Check logs above for specific errors"
    Write-Host "   2. Try restarting: .\stop.ps1 && .\start.ps1"
    Write-Host "   3. If port conflict: Change PORT in .env"
    Write-Host "   4. If persistent issues: Remove volume and restart"
    Write-Host "      docker volume rm standalone_broker_pgdata"
    Write-Host "      .\start.ps1"
}

Write-Host ""
Write-Host "=== DIAGNOSTICS COMPLETE ===" -ForegroundColor Green
