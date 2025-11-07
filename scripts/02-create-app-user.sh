#!/bin/bash
set -e

# This script creates the application user with password from environment variable
# Runs after schema.sql during database initialization

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create dedicated application user for production
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'broker_app') THEN
            CREATE USER broker_app WITH PASSWORD '${BROKER_APP_PASSWORD}';
        END IF;
    END
    \$\$;

    -- Grant permissions
    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO broker_app;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO broker_app;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO broker_app;
    GRANT ALL PRIVILEGES ON SCHEMA public TO broker_app;

    -- Grant default privileges for future tables
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO broker_app;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO broker_app;
EOSQL
