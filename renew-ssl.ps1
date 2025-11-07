# Renew Let's Encrypt SSL certificates
# Run this script every 60 days or set up as scheduled task

Write-Host "=== RENEWING LET'S ENCRYPT CERTIFICATE ===" -ForegroundColor Green
Write-Host ""

# Check if letsencrypt directory exists
if (!(Test-Path ".\letsencrypt")) {
    Write-Host "❌ No Let's Encrypt certificates found!" -ForegroundColor Red
    Write-Host "Run generate-ssl-letsencrypt-docker.ps1 first" -ForegroundColor Yellow
    exit 1
}

Write-Host "Checking certificate expiry..." -ForegroundColor Yellow

# Run renewal
docker run --rm `
    -p 80:80 `
    -v "${PWD}\letsencrypt:/etc/letsencrypt" `
    certbot/certbot renew

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Certificate renewal successful!" -ForegroundColor Green
    Write-Host ""
    
    # Find the domain directory
    $domains = Get-ChildItem ".\letsencrypt\live" -Directory
    if ($domains.Count -gt 0) {
        $domain = $domains[0].Name
        Write-Host "Updating certificates for: $domain" -ForegroundColor Cyan
        
        # Copy new certificates
        Copy-Item ".\letsencrypt\live\$domain\fullchain.pem" -Destination ".\server.crt" -Force
        Copy-Item ".\letsencrypt\live\$domain\privkey.pem" -Destination ".\server.key" -Force
        
        # Set permissions
        icacls server.key /inheritance:r /grant:r "${env:USERNAME}:R" | Out-Null
        
        Write-Host "✅ Certificates updated!" -ForegroundColor Green
        Write-Host ""
        Write-Host "⚠️  Database restart required:" -ForegroundColor Yellow
        
        $restart = Read-Host "Restart production database now? (yes/no)"
        if ($restart -eq "yes") {
            Write-Host "Restarting database..." -ForegroundColor Yellow
            docker compose -f docker-compose.prod.yaml restart postgres
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Database restarted with new certificates!" -ForegroundColor Green
            } else {
                Write-Host "❌ Failed to restart database" -ForegroundColor Red
            }
        } else {
            Write-Host "⚠️  Remember to restart database manually:" -ForegroundColor Yellow
            Write-Host "  .\stop-prod.ps1"
            Write-Host "  .\start-prod.ps1"
        }
    }
    
} else {
    Write-Host "ℹ️  No renewal needed (certificates still valid)" -ForegroundColor Cyan
    Write-Host "Certificates are automatically renewed when <30 days remain" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== RENEWAL COMPLETE ===" -ForegroundColor Green
