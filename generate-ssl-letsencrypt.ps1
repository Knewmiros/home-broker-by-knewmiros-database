# Get SSL Certificate from Let's Encrypt using Certbot
# For production PostgreSQL database

Write-Host "=== LET'S ENCRYPT CERTIFICATE SETUP ===" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  REQUIREMENTS:" -ForegroundColor Yellow
Write-Host "1. A registered domain name pointing to your server"
Write-Host "2. Port 80 must be accessible from the internet (for verification)"
Write-Host "3. Certbot installed on your system"
Write-Host ""

$domain = Read-Host "Enter your domain name (e.g., db.yourdomain.com)"
$email = Read-Host "Enter your email address (for renewal notifications)"

if ($domain -eq "" -or $email -eq "") {
    Write-Host "❌ Domain and email are required!" -ForegroundColor Red
    exit 1
}

Write-Host "`nℹ️  This script will guide you through Let's Encrypt setup" -ForegroundColor Cyan
Write-Host ""

# Check if Certbot is installed
$certbotInstalled = Get-Command certbot -ErrorAction SilentlyContinue

if (!$certbotInstalled) {
    Write-Host "❌ Certbot is not installed" -ForegroundColor Red
    Write-Host ""
    Write-Host "📦 Install Certbot:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Option 1 - Using Chocolatey (Windows):"
    Write-Host "  choco install certbot"
    Write-Host ""
    Write-Host "Option 2 - Download installer:"
    Write-Host "  https://certbot.eff.org/instructions"
    Write-Host ""
    Write-Host "Option 3 - Use Docker (see generate-ssl-letsencrypt-docker.ps1)"
    exit 1
}

Write-Host "✅ Certbot is installed" -ForegroundColor Green
Write-Host ""
Write-Host "🔐 Generating certificate for: $domain" -ForegroundColor Cyan
Write-Host ""

# Generate certificate using standalone mode
Write-Host "Running Certbot (this may take a minute)..." -ForegroundColor Yellow
Write-Host "Certbot will verify domain ownership via HTTP challenge (port 80)" -ForegroundColor Gray
Write-Host ""

certbot certonly --standalone `
    --preferred-challenges http `
    --email $email `
    --agree-tos `
    --no-eff-email `
    -d $domain

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Certificate obtained successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Copy certificates to project directory
    $certPath = "C:\Certbot\live\$domain"
    
    if (Test-Path $certPath) {
        Write-Host "Copying certificates to project directory..." -ForegroundColor Yellow
        Copy-Item "$certPath\fullchain.pem" -Destination ".\server.crt" -Force
        Copy-Item "$certPath\privkey.pem" -Destination ".\server.key" -Force
        
        # Set permissions
        icacls server.key /inheritance:r /grant:r "${env:USERNAME}:R" | Out-Null
        
        Write-Host "✅ Certificates copied to:" -ForegroundColor Green
        Write-Host "  - server.crt (certificate)"
        Write-Host "  - server.key (private key)"
        Write-Host ""
        Write-Host "📋 Certificate Details:" -ForegroundColor Cyan
        Write-Host "  Domain: $domain"
        Write-Host "  Location: $certPath"
        Write-Host "  Valid for: 90 days"
        Write-Host ""
        Write-Host "⚠️  IMPORTANT:" -ForegroundColor Yellow
        Write-Host "1. Let's Encrypt certificates expire in 90 days"
        Write-Host "2. Set up auto-renewal with: certbot renew --dry-run"
        Write-Host "3. Schedule renewal task to run twice daily"
        Write-Host "4. After renewal, copy new certificates and restart database"
        Write-Host ""
        Write-Host "🔄 Auto-Renewal Setup:" -ForegroundColor Cyan
        Write-Host "  Create a scheduled task to run:"
        Write-Host "  certbot renew --post-hook 'Copy-Item C:\Certbot\live\$domain\*.pem .\'"
    } else {
        Write-Host "⚠️  Certificate path not found: $certPath" -ForegroundColor Yellow
        Write-Host "Certificates are typically located in:" -ForegroundColor Gray
        Write-Host "  Windows: C:\Certbot\live\$domain\"
        Write-Host "  Linux: /etc/letsencrypt/live/$domain/"
    }
    
} else {
    Write-Host ""
    Write-Host "❌ Certificate generation failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "1. Domain doesn't point to this server's IP"
    Write-Host "2. Port 80 is blocked by firewall"
    Write-Host "3. Another service is using port 80"
    Write-Host "4. DNS propagation not complete (wait 24 hours after DNS change)"
    exit 1
}

Write-Host "=== SETUP COMPLETE ===" -ForegroundColor Green
