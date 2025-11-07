# Production Deployment Checklist

## Pre-Deployment

### 1. Security

- [x] Change all default passwords in `.env`
- [x] Generate strong random passwords (min 32 characters)
- [x] Never commit `.env` file to git
- [x] Remove `POSTGRES_HOST_AUTH_METHOD: trust` from docker-compose
- [ ] Enable SSL/TLS certificates
- [ ] Configure firewall rules (only allow necessary ports)
- [ ] Use non-default port if exposed to internet

### 2. SSL/TLS Setup

**For Development/Testing (Self-Signed Certificates):**

```powershell
# Quick self-signed certificate (development only)
.\generate-ssl-docker.ps1
```

**For Production (Trusted Certificates from Let's Encrypt):**

Let's Encrypt provides FREE, trusted SSL certificates. Choose one method:

**Method 1: Docker + Let's Encrypt (Recommended - No installation needed)**

```powershell
# One-time setup
.\generate-ssl-letsencrypt-docker.ps1

# Renewal (every 60-80 days)
.\renew-ssl.ps1
```

**Method 2: Certbot + Let's Encrypt (Traditional)**

```powershell
# Install Certbot first: choco install certbot
.\generate-ssl-letsencrypt.ps1

# Auto-renewal setup in Task Scheduler
```

**Requirements for Let's Encrypt:**

- A registered domain name pointing to your server
- Port 80 accessible from internet (for domain verification)
- Valid email address for renewal notifications

**Alternative Methods (Self-Signed - Development Only):**

Using OpenSSL:

```bash
openssl req -new -x509 -days 365 -nodes -text -out server.crt -keyout server.key -subj "/CN=broker_db"
# On Windows:
icacls server.key /inheritance:r /grant:r "${env:USERNAME}:R"
```

Using PowerShell:

```powershell
.\generate-ssl.ps1
```

Mount certificates in docker-compose.prod.yaml:

```yaml
volumes:
  - ./server.crt:/var/lib/postgresql/server.crt
  - ./server.key:/var/lib/postgresql/server.key
```

**Note:** For production, obtain certificates from a trusted Certificate Authority (Let's Encrypt, DigiCert, etc.)

### 3. Backup Strategy

- [ ] Set up automated daily backups (cron job)
- [ ] Test backup restoration process
- [ ] Store backups in separate location (cloud storage)
- [ ] Implement backup retention policy (keep 30 days)
- [ ] Document backup/restore procedures

### 4. Monitoring

- [ ] Set up database monitoring (pg_stat_statements)
- [ ] Configure alerting for disk space
- [ ] Monitor connection count
- [ ] Track slow queries
- [ ] Set up log aggregation

### 5. Performance

- [ ] Tune PostgreSQL configuration for production workload
- [ ] Set appropriate shared_buffers (25% of RAM)
- [ ] Configure connection pooling (PgBouncer recommended)
- [ ] Add appropriate indexes based on query patterns
- [ ] Run VACUUM and ANALYZE regularly

### 6. Network Security

- [ ] Use Docker networks (do NOT expose port 5432 publicly)
- [ ] Backend should connect via Docker network, not host port
- [ ] If remote access needed, use SSH tunnel or VPN
- [ ] Enable SSL requirement: `POSTGRES_INITDB_ARGS: "--auth-host=scram-sha-256"`

### 7. Access Control

- [ ] Create separate users for different services
- [ ] Grant minimum required privileges
- [ ] Disable remote login for superuser (postgres)
- [ ] Use `broker_app` user for application connections
- [ ] Regularly audit user permissions

### 8. Data Protection

- [ ] Enable point-in-time recovery (PITR) with WAL archiving
- [ ] Set up replication for high availability (optional)
- [ ] Encrypt backups before storing
- [ ] Implement data retention policies
- [ ] Regular security audits

### 9. Docker Configuration

- [ ] Use `restart: always` instead of `unless-stopped`
- [ ] Set resource limits (CPU, memory)
- [ ] Use specific image tags, not `latest`
- [ ] Enable Docker health checks
- [ ] Configure logging driver

### 10. Environment

- [ ] Use production docker-compose file: `docker-compose.prod.yaml`
- [ ] Set NODE_ENV=production (or equivalent)
- [ ] Remove development tools and data
- [ ] Disable verbose logging
- [ ] Configure proper log rotation

## Deployment Commands

### Initial Setup

```powershell
# Copy and configure environment
cp .env.example .env
# Edit .env with production values

# Use production compose file
docker compose -f docker-compose.prod.yaml up -d

# Verify
docker compose -f docker-compose.prod.yaml ps
```

### Regular Operations

```powershell
# Start
docker compose -f docker-compose.prod.yaml up -d

# View logs
docker compose -f docker-compose.prod.yaml logs -f

# Backup
.\backup.ps1 -BackupType complete

# Stop
docker compose -f docker-compose.prod.yaml down
```

## Recommended Environment Variables (.env)

```bash
# PostgreSQL Super User (for admin tasks only)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<generate-strong-password-here>
POSTGRES_DB=broker_db
PORT=5432:5432

# Application User Password (used in schema.sql)
BROKER_APP_PASSWORD=<generate-strong-password-here>

# Backup Configuration
BACKUP_RETENTION_DAYS=30
BACKUP_S3_BUCKET=<your-backup-bucket>
```

## Post-Deployment

- [ ] Test all application functionality
- [ ] Verify backup restoration
- [ ] Monitor resource usage for 48 hours
- [ ] Document any issues encountered
- [ ] Create runbook for common operations
- [ ] Train team on production procedures

## Security Audit Schedule

- [ ] Weekly: Review access logs
- [ ] Monthly: Test backup restoration
- [ ] Monthly: Update dependencies and patches
- [ ] Quarterly: Security assessment
- [ ] Yearly: Comprehensive security audit
