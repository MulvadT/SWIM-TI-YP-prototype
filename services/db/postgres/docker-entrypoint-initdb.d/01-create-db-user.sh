#!/bin/bash
set -e

echo "Creating database '${DB_NAME}' and user '${DB_USER}'..."

# Create the application database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create the application database
    CREATE DATABASE ${DB_NAME};
    
    -- Create the application database user
    CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';
    
    -- Grant necessary privileges on the database
    GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
EOSQL

# Connect to the application database and grant schema privileges
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB_NAME" <<-EOSQL
    -- Grant schema privileges
    GRANT ALL ON SCHEMA public TO ${DB_USER};
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
    
    -- Set default privileges for future objects
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
EOSQL

echo "Database '${DB_NAME}' and user '${DB_USER}' created successfully!"

