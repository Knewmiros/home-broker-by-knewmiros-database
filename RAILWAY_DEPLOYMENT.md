# Deploying to Railway with Automated Backups

## Overview

Railway is a cloud platform that doesn't support Windows Task Scheduler. Instead, we use:

- **Railway Cron Jobs** for scheduled backups
- **Cloud storage** (S3) for backup storage
- **Railway environment variables** for configuration

---

## Deployment Steps

### 1. Deploy PostgreSQL Database

#### Option A: Using Railway's PostgreSQL Template

1. Go to Railway dashboard
2. Click "New Project" → "Deploy PostgreSQL"
3. Railway automatically provisions:
   - PostgreSQL database
   - Environment variables (automatically set)
   - Persistent volume

#### Option B: Using Docker Compose (Custom)

1. Create `railway.toml`:

```toml
[build]
builder = "dockerfile"
dockerfilePath = "Dockerfile"

[deploy]
startCommand = "docker-compose -f docker-compose.prod.yaml up"
restartPolicyType = "always"
```

2. Push to GitHub/GitLab
3. Connect repository to Railway

---

### 2. Set Up Automated Backups

Railway doesn't support traditional cron in the database container, so we create a **separate cron job service**.

#### Create Backup Cron Service

1. **In Railway Dashboard:**

   - Click "New Service" in your project
   - Choose "Empty Service"
   - Name it: "db-backup-cron"

2. **Configure Service:**

   - Set build context to use `Dockerfile.backup`
   - Or connect to GitHub and specify dockerfile path

3. **Set Environment Variables:**

```bash
# Database connection (these are automatically available from Railway PostgreSQL)
PGHOST=${{Postgres.PGHOST}}
PGPORT=${{Postgres.PGPORT}}
POSTGRES_DB=${{Postgres.PGDATABASE}}
POSTGRES_USER=${{Postgres.PGUSER}}
POSTGRES_PASSWORD=${{Postgres.PGPASSWORD}}

# AWS S3 for backup storage
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_S3_BUCKET=your-backup-bucket
AWS_DEFAULT_REGION=us-east-1

# Backup configuration
BACKUP_RETENTION_DAYS=30
```

4. **Set Cron Schedule:**
   - In Railway service settings
   - Set "Cron Schedule": `0 2 * * *` (2 AM daily)
   - Or use Railway's cron syntax

---

### 3. Alternative: Use Railway's Built-in Backups

Railway PostgreSQL includes automatic backups:

1. **Access Backups:**

   - Go to PostgreSQL service in Railway
   - Click "Backups" tab
   - Railway automatically backs up daily

2. **Restore from Railway Backup:**
   - In Railway dashboard → Backups
   - Click backup → "Restore"
   - Choose target environment

**Limitations:**

- ⚠️ Only available on paid plans
- ⚠️ Limited retention (usually 7 days)
- ⚠️ No custom schedule

---

### 4. Set Up S3 Bucket for Backups

Since Railway has limited local storage, use S3:

```bash
# 1. Create S3 bucket
aws s3 mb s3://railway-broker-db-backups

# 2. Set lifecycle policy (auto-delete after 90 days)
aws s3api put-bucket-lifecycle-configuration \
  --bucket railway-broker-db-backups \
  --lifecycle-configuration file://s3-lifecycle.json
```

**s3-lifecycle.json:**

```json
{
  "Rules": [
    {
      "Id": "Delete old backups",
      "Status": "Enabled",
      "Prefix": "railway-backups/",
      "Expiration": {
        "Days": 90
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 60,
          "StorageClass": "GLACIER"
        }
      ]
    }
  ]
}
```

---

### 5. Manual Backup from Railway

If you need to create a manual backup:

#### Method 1: Railway CLI

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Link to project
railway link

# Create backup
railway run bash -c "pg_dump \$DATABASE_URL > backup.sql"

# Download backup
railway run cat backup.sql > local_backup.sql
```

#### Method 2: Connect and Backup Locally

```bash
# Get connection string from Railway dashboard
railway variables

# Backup locally
pg_dump "postgresql://user:pass@host:port/db" > backup.sql

# Or use the backup script
export PGHOST=railway-host.railway.app
export PGPORT=5432
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=your_password
export POSTGRES_DB=railway

bash backup-railway.sh
```

---

### 6. Restore Backup to Railway

```bash
# Using Railway CLI
railway run bash -c "psql \$DATABASE_URL < backup.sql"

# Or directly with psql
psql "postgresql://user:pass@host:port/db" < backup.sql
```

---

## Architecture Comparison

### Local Development

```
┌─────────────────┐
│ Your Computer   │
│                 │
│ Docker Desktop  │
│ ├─ PostgreSQL   │
│ └─ Volumes      │
│                 │
│ Task Scheduler  │◄── Runs backup-automated.ps1
│ ├─ Daily 2 AM   │
│ └─ Backups/     │
└─────────────────┘
```

### Railway Production

```
┌─────────────────────┐
│ Railway Platform    │
│                     │
│ ┌─────────────────┐ │
│ │ PostgreSQL DB   │ │
│ │ (Managed)       │ │
│ └────────┬────────┘ │
│          │          │
│ ┌────────▼────────┐ │
│ │ Backup Cron Job │ │◄── Runs daily (Railway Cron)
│ │ (Separate Svc)  │ │
│ └────────┬────────┘ │
│          │          │
└──────────┼──────────┘
           │
           ▼
    ┌──────────────┐
    │   AWS S3     │
    │   Backups    │
    │   (Storage)  │
    └──────────────┘
```

---

## Cost Considerations

| Component           | Cost (Approx)                |
| ------------------- | ---------------------------- |
| Railway PostgreSQL  | $5-20/month (1GB-4GB)        |
| Railway Backup Cron | $0-5/month (minimal compute) |
| AWS S3 Storage      | ~$0.023/GB/month             |
| Data Transfer       | Usually minimal              |

**Example**:

- 1GB database
- Daily backups (30 days retention)
- Total: ~$10-15/month

---

## Environment Variables for Railway

Add these to your Railway project:

```bash
# Automatically set by Railway PostgreSQL
DATABASE_URL=postgresql://...
PGHOST=...
PGPORT=5432
PGUSER=postgres
PGPASSWORD=...
PGDATABASE=railway

# Manual configuration needed
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_S3_BUCKET=railway-broker-backups
BACKUP_RETENTION_DAYS=30

# Optional: Notifications
WEBHOOK_URL=https://hooks.slack.com/...  # For backup notifications
```

---

## Monitoring Backups

### Check S3 Backups

```bash
# List backups in S3
aws s3 ls s3://railway-broker-backups/railway-backups/

# Download specific backup
aws s3 cp s3://railway-broker-backups/railway-backups/backup_20251107.sql.gz .
```

### Check Railway Logs

```bash
# View cron job logs
railway logs --service db-backup-cron

# Follow logs in real-time
railway logs --service db-backup-cron --follow
```

---

## Troubleshooting

### Backup Cron Not Running

```bash
# Check service status
railway status

# View logs
railway logs --service db-backup-cron

# Manually trigger (for testing)
railway run --service db-backup-cron /usr/local/bin/backup-railway.sh
```

### Connection Issues

```bash
# Test database connection
railway run psql $DATABASE_URL -c "SELECT version();"

# Check environment variables
railway variables
```

### S3 Upload Failures

```bash
# Test AWS credentials
aws s3 ls s3://your-bucket/

# Check Railway environment has AWS vars
railway variables | grep AWS
```

---

## Migration from Local to Railway

1. **Backup local database:**

```powershell
.\backup.ps1 -BackupType all
```

2. **Upload to S3:**

```powershell
aws s3 cp backups\latest.sql s3://bucket/migration/
```

3. **Restore to Railway:**

```bash
# Download from S3 to Railway
railway run bash -c "
  curl -o /tmp/backup.sql https://s3.amazonaws.com/bucket/migration/backup.sql
  psql \$DATABASE_URL < /tmp/backup.sql
"
```

---

## Quick Setup Checklist

- [ ] Deploy PostgreSQL on Railway
- [ ] Create S3 bucket for backups
- [ ] Set up AWS IAM user with S3 access
- [ ] Create backup cron service in Railway
- [ ] Configure environment variables
- [ ] Test manual backup
- [ ] Verify cron schedule
- [ ] Test backup restoration
- [ ] Set up monitoring/alerts

---

**For Railway, you CANNOT use Windows Task Scheduler. Use Railway Cron Jobs + S3 instead!**
