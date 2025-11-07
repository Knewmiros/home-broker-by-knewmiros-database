# Generate SSL certificate for PostgreSQL
Write-Host "=== GENERATING SSL CERTIFICATE ===" -ForegroundColor Green

# Certificate parameters
$certName = "broker_db"
$validDays = 365
$certPath = ".\server.crt"
$keyPath = ".\server.key"

Write-Host "Generating self-signed certificate..." -ForegroundColor Yellow
Write-Host "Common Name: $certName"
Write-Host "Valid for: $validDays days"

# Create a self-signed certificate
$cert = New-SelfSignedCertificate `
    -DnsName $certName `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -NotAfter (Get-Date).AddDays($validDays) `
    -KeySpec KeyExchange `
    -KeyExportPolicy Exportable

Write-Host "✅ Certificate created" -ForegroundColor Green

# Export certificate (public key)
Export-Certificate -Cert $cert -FilePath $certPath -Force | Out-Null
Write-Host "✅ Certificate exported to: $certPath" -ForegroundColor Green

# Export private key
$password = ConvertTo-SecureString -String "temp" -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath ".\temp.pfx" -Password $password -Force | Out-Null

# Convert PFX to PEM format (required for PostgreSQL)
if (Get-Command openssl -ErrorAction SilentlyContinue) {
    Write-Host "Converting to PEM format..." -ForegroundColor Yellow
    openssl pkcs12 -in ".\temp.pfx" -nocerts -nodes -out $keyPath -password pass:temp
    openssl pkcs12 -in ".\temp.pfx" -clcerts -nokeys -out $certPath -password pass:temp
    Remove-Item ".\temp.pfx" -Force
    Write-Host "✅ Private key exported to: $keyPath" -ForegroundColor Green
} else {
    Write-Host "⚠️  OpenSSL not found - using Windows certificate format" -ForegroundColor Yellow
    Write-Host "For production, install OpenSSL to generate proper PEM format" -ForegroundColor Yellow
    Write-Host "Or use Option 3 below (Docker-based generation)" -ForegroundColor Cyan
}

# Remove certificate from store
Remove-Item -Path "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force

# Set file permissions (Windows)
Write-Host "Setting file permissions..." -ForegroundColor Yellow
if (Test-Path $keyPath) {
    icacls $keyPath /inheritance:r /grant:r "${env:USERNAME}:R" | Out-Null
    Write-Host "✅ Permissions set on private key" -ForegroundColor Green
}

Write-Host "`n=== SSL CERTIFICATE GENERATION COMPLETE ===" -ForegroundColor Green
Write-Host "Files created:"
if (Test-Path $certPath) {
    Write-Host "  - $certPath (public certificate)"
}
if (Test-Path $keyPath) {
    Write-Host "  - $keyPath (private key)"
}

Write-Host "`n⚠️  IMPORTANT:" -ForegroundColor Yellow
Write-Host "1. Never commit these files to git (already in .gitignore)"
Write-Host "2. For production, use certificates from a trusted CA"
Write-Host "3. Update docker-compose.prod.yaml to mount these files"
