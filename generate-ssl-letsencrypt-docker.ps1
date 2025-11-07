# Get SSL Certificate from Let's Encrypt using Docker
# No need to install Certbot locally

Write-Host "=== LET'S ENCRYPT CERTIFICATE (Docker) ===" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  REQUIREMENTS:" -ForegroundColor Yellow
Write-Host "1. A registered domain name (e.g., db.yourdomain.com)"
Write-Host "2. Domain must point to this server's public IP"
Write-Host "3. Port 80 must be accessible from the internet"
Write-Host "4. Docker must be running"
Write-Host ""

$domain = Read-Host "Enter your domain name"
$email = Read-Host "Enter your email address"

if ($domain -eq "" -or $email -eq "") {
    Write-Host "❌ Domain and email are required!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🔐 Obtaining certificate for: $domain" -ForegroundColor Cyan
Write-Host "📧 Email: $email" -ForegroundColor Cyan
Write-Host ""

# Create directory for Let's Encrypt data
$letsencryptDir = ".\letsencrypt"
if (!(Test-Path $letsencryptDir)) {
    New-Item -ItemType Directory -Path $letsencryptDir | Out-Null
}

Write-Host "Running Certbot in Docker container..." -ForegroundColor Yellow
Write-Host "This may take a minute..." -ForegroundColor Gray
Write-Host ""

# Run Certbot in Docker
docker run --rm `
    -p 80:80 `
    -v "${PWD}\letsencrypt:/etc/letsencrypt" `
    certbot/certbot certonly `
    --standalone `
    --preferred-challenges http `
    --email $email `
    --agree-tos `
    --no-eff-email `
    -d $domain

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Certificate obtained successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Copy certificates to project root
    $certSourcePath = ".\letsencrypt\live\$domain"
    
    if (Test-Path "$certSourcePath\fullchain.pem") {
        Write-Host "Copying certificates..." -ForegroundColor Yellow
        Copy-Item "$certSourcePath\fullchain.pem" -Destination ".\server.crt" -Force
        Copy-Item "$certSourcePath\privkey.pem" -Destination ".\server.key" -Force
        
        # Set permissions
        icacls server.key /inheritance:r /grant:r "${env:USERNAME}:R" | Out-Null
        
        Write-Host "✅ Certificates ready!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📄 Files created:" -ForegroundColor Cyan
        Write-Host "  - server.crt (certificate)"
        Write-Host "  - server.key (private key)"
        Write-Host ""
        Write-Host "📋 Certificate Info:" -ForegroundColor Cyan
        Write-Host "  Domain: $domain"
        Write-Host "  Issuer: Let's Encrypt"
        Write-Host "  Valid for: 90 days"
        Write-Host "  Auto-renewable: Yes"
        Write-Host ""
        Write-Host "🔄 TO RENEW (every 60-80 days):" -ForegroundColor Yellow
        Write-Host "  docker run --rm ``"
        Write-Host "    -p 80:80 ``"
        Write-Host "    -v `"`${PWD}\letsencrypt:/etc/letsencrypt`" ``"
        Write-Host "    certbot/certbot renew"
        Write-Host ""
        Write-Host "  Then copy new certificates:"
        Write-Host "  Copy-Item .\letsencrypt\live\$domain\fullchain.pem .\server.crt -Force"
        Write-Host "  Copy-Item .\letsencrypt\live\$domain\privkey.pem .\server.key -Force"
        Write-Host ""
        Write-Host "⚠️  NEXT STEPS:" -ForegroundColor Yellow
        Write-Host "1. Update docker-compose.prod.yaml to mount certificates"
        Write-Host "2. Restart database: .\stop-prod.ps1 then .\start-prod.ps1"
        Write-Host "3. Set up auto-renewal (Task Scheduler or cron)"
        
    } else {
        Write-Host "❌ Certificate files not found at expected location" -ForegroundColor Red
    }
    
} else {
    Write-Host ""
    Write-Host "❌ Failed to obtain certificate!" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Verify domain points to this server:"
    Write-Host "   nslookup $domain"
    Write-Host ""
    Write-Host "2. Check if port 80 is accessible:"
    Write-Host "   Test-NetConnection -ComputerName $domain -Port 80"
    Write-Host ""
    Write-Host "3. Ensure no other service is using port 80:"
    Write-Host "   netstat -ano | findstr :80"
    Write-Host ""
    Write-Host "4. Check firewall allows inbound port 80"
    Write-Host ""
    Write-Host "5. Wait 24 hours after changing DNS records"
    exit 1
}

Write-Host ""
Write-Host "=== SETUP COMPLETE ===" -ForegroundColor Green
