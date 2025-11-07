#!/bin/bash
# Backup script for Railway/Cloud environments
# This runs as a cron job in Railway

set -e

echo "=== RAILWAY BACKUP STARTED ==="
date

# Database connection from Railway environment variables
DB_HOST=${PGHOST:-localhost}
DB_PORT=${PGPORT:-5432}
DB_NAME=${POSTGRES_DB:-broker_db}
DB_USER=${POSTGRES_USER:-postgres}
DB_PASSWORD=${POSTGRES_PASSWORD}

# Backup configuration
BACKUP_DIR="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/backup_all_${TIMESTAMP}.sql"
RETENTION_DAYS=30

# Ensure backup directory exists
mkdir -p ${BACKUP_DIR}

echo "Creating backup: ${BACKUP_FILE}"

# Create backup using pg_dumpall
PGPASSWORD=${DB_PASSWORD} pg_dumpall \
  -h ${DB_HOST} \
  -p ${DB_PORT} \
  -U ${DB_USER} \
  > ${BACKUP_FILE}

if [ $? -eq 0 ]; then
    echo "✅ Backup created successfully"
    
    # Compress backup
    gzip ${BACKUP_FILE}
    echo "✅ Backup compressed: ${BACKUP_FILE}.gz"
    
    # Get file size
    SIZE=$(du -h "${BACKUP_FILE}.gz" | cut -f1)
    echo "📏 Backup size: ${SIZE}"
    
    # Upload to cloud storage (if configured)
    if [ ! -z "$AWS_S3_BUCKET" ]; then
        echo "Uploading to S3..."
        aws s3 cp "${BACKUP_FILE}.gz" "s3://${AWS_S3_BUCKET}/railway-backups/$(basename ${BACKUP_FILE}.gz)" \
            --storage-class STANDARD_IA
        echo "✅ Uploaded to S3"
    fi
    
    # Clean old backups (older than RETENTION_DAYS)
    echo "Cleaning old backups..."
    find ${BACKUP_DIR} -name "backup_*.sql.gz" -type f -mtime +${RETENTION_DAYS} -delete
    echo "✅ Old backups cleaned"
    
    # List current backups
    echo ""
    echo "📋 Current backups:"
    ls -lh ${BACKUP_DIR}/backup_*.sql.gz 2>/dev/null || echo "No compressed backups found"
    
else
    echo "❌ Backup failed!"
    exit 1
fi

echo "=== RAILWAY BACKUP COMPLETED ==="
date
