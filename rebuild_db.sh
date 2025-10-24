#!/usr/bin/env bash
set -euo pipefail

# --- Required env vars ---
: "${POSTGRES_USER:?Set POSTGRES_USER (e.g. postg_user)}"
: "${DB_USER:?Set DB_USER (e.g. sm_user)}"
: "${DB_PASS:?Set DB_PASS}"

# --- Static values ---
POSTGRES_CONTAINER_NAME="swim-postgres"
DB_NAMES=("smdb" "testing")
LC_ALL_IN_DB="en_US.UTF-8"

# --- Locate running container ---
POSTGRES_ID=$(docker ps | grep -F "$POSTGRES_CONTAINER_NAME" | awk '{print $1}' | head -n1)
if [[ -z "$POSTGRES_ID" ]]; then
  echo "❌ No running container named '${POSTGRES_CONTAINER_NAME}' found."
  exit 1
else
  echo "✅ Found container: $POSTGRES_ID"
fi

# --- Helper: psql as POSTGRES_USER (no explicit DB) ---
psql_exec() {
  docker exec -i "$POSTGRES_ID" psql -U "$POSTGRES_USER" -v ON_ERROR_STOP=1
}

# --- Enforce SCRAM password encryption ---
psql_exec <<'SQL'
ALTER SYSTEM SET password_encryption = 'scram-sha-256';
SELECT pg_reload_conf();
SQL

# --- Create or update application user ---
psql_exec <<SQL
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${DB_USER}') THEN
      CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';
   ELSE
      ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASS}';
   END IF;
END
\$\$;
SQL

# --- Create databases and grant privileges (drop first if exists) ---
for DB in "${DB_NAMES[@]}"; do
psql_exec <<SQL
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '${DB}'
  AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS ${DB};

CREATE DATABASE ${DB}
  WITH OWNER = ${DB_USER}
       TEMPLATE = template0
       ENCODING = 'UTF8'
       LC_COLLATE = '${LC_ALL_IN_DB}'
       LC_CTYPE   = '${LC_ALL_IN_DB}';
GRANT ALL PRIVILEGES ON DATABASE ${DB} TO ${DB_USER};
SQL
done


# --- Per-database privileges ---
for DB in "${DB_NAMES[@]}"; do
docker exec -i "$POSTGRES_ID" psql -U "$POSTGRES_USER" -d "$DB" -v ON_ERROR_STOP=1 <<SQL
ALTER SCHEMA public OWNER TO ${DB_USER};
GRANT ALL PRIVILEGES ON SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_USER};
SQL
done

echo "✅ Databases (${DB_NAMES[*]}) and user '${DB_USER}' created successfully (connected as ${POSTGRES_USER})."
