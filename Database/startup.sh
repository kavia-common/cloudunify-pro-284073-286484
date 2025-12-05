#!/bin/bash

# Minimal PostgreSQL startup script with full paths
DB_NAME="myapp"
DB_USER="appuser"
DB_PASSWORD="dbuser123"
DB_PORT="5000"

echo "Starting PostgreSQL setup..."

# Find PostgreSQL version and set paths
PG_VERSION=$(ls /usr/lib/postgresql/ | head -1)
PG_BIN="/usr/lib/postgresql/${PG_VERSION}/bin"

echo "Found PostgreSQL version: ${PG_VERSION}"

# Check if PostgreSQL is already running on the specified port
if sudo -u postgres ${PG_BIN}/pg_isready -p ${DB_PORT} > /dev/null 2>&1; then
    echo "PostgreSQL is already running on port ${DB_PORT}!"
    echo "Database: ${DB_NAME}"
    echo "User: ${DB_USER}"
    echo "Port: ${DB_PORT}"
    echo ""
    echo "To connect to the database, use:"
    echo "psql -h localhost -U ${DB_USER} -d ${DB_NAME} -p ${DB_PORT}"
    
    # Check if connection info file exists
    if [ -f "db_connection.txt" ]; then
        echo "Or use: $(cat db_connection.txt)"
    fi
    
    echo ""
    echo "Script stopped - server already running."
    # Even when already running, we continue to handle optional viewer (below)
else
    # Also check if there's a PostgreSQL process running (in case pg_isready fails)
    if pgrep -f "postgres.*-p ${DB_PORT}" > /dev/null 2>&1; then
        echo "Found existing PostgreSQL process on port ${DB_PORT}"
        echo "Attempting to verify connection..."
        
        # Try to connect and verify the database exists
        if sudo -u postgres ${PG_BIN}/psql -p ${DB_PORT} -d ${DB_NAME} -c '\q' 2>/dev/null; then
            echo "Database ${DB_NAME} is accessible."
            echo "Script stopped - server already running."
        fi
    fi

    # Initialize PostgreSQL data directory if it doesn't exist
    if [ ! -f "/var/lib/postgresql/data/PG_VERSION" ]; then
        echo "Initializing PostgreSQL..."
        sudo -u postgres ${PG_BIN}/initdb -D /var/lib/postgresql/data
    fi

    # Start PostgreSQL server in background
    echo "Starting PostgreSQL server..."
    sudo -u postgres ${PG_BIN}/postgres -D /var/lib/postgresql/data -p ${DB_PORT} &

    # Wait for PostgreSQL to start
    echo "Waiting for PostgreSQL to start..."
    sleep 5

    # Check if PostgreSQL is running
    for i in {1..15}; do
        if sudo -u postgres ${PG_BIN}/pg_isready -p ${DB_PORT} > /dev/null 2>&1; then
            echo "PostgreSQL is ready!"
            break
        fi
        echo "Waiting... ($i/15)"
        sleep 2
    done

    # Create database and user
    echo "Setting up database and user..."
    sudo -u postgres ${PG_BIN}/createdb -p ${DB_PORT} ${DB_NAME} 2>/dev/null || echo "Database might already exist"

    # Set up user and permissions with proper schema ownership
    sudo -u postgres ${PG_BIN}/psql -p ${DB_PORT} -d postgres << EOF
-- Create user if doesn't exist
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}') THEN
        CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}';
    END IF;
    ALTER ROLE ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
END
\$\$;

-- Grant database-level permissions
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};

-- Connect to the specific database for schema-level permissions
\\c ${DB_NAME}

-- For PostgreSQL 15+, we need to handle public schema permissions differently
-- First, grant usage on public schema
GRANT USAGE ON SCHEMA public TO ${DB_USER};

-- Grant CREATE permission on public schema
GRANT CREATE ON SCHEMA public TO ${DB_USER};

-- Make the user owner of all future objects they create in public schema
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TYPES TO ${DB_USER};

-- If you want the user to be able to create objects without restrictions,
-- you can make them the owner of the public schema (optional but effective)
-- ALTER SCHEMA public OWNER TO ${DB_USER};

-- Alternative: Grant all privileges on schema public to the user
GRANT ALL ON SCHEMA public TO ${DB_USER};

-- Ensure the user can work with any existing objects
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_USER};
EOF

    # Additionally, connect to the specific database to ensure permissions
    sudo -u postgres ${PG_BIN}/psql -p ${DB_PORT} -d ${DB_NAME} << EOF
-- Double-check permissions are set correctly in the target database
GRANT ALL ON SCHEMA public TO ${DB_USER};
GRANT CREATE ON SCHEMA public TO ${DB_USER};

-- Show current permissions for debugging
\\dn+ public
EOF

    # Save connection command to a file
    echo "psql postgresql://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}" > db_connection.txt
    echo "Connection string saved to db_connection.txt"

    # Save environment variables to a file
    cat > db_visualizer/postgres.env << EOF
export POSTGRES_URL="postgresql://localhost:${DB_PORT}/${DB_NAME}"
export POSTGRES_USER="${DB_USER}"
export POSTGRES_PASSWORD="${DB_PASSWORD}"
export POSTGRES_DB="${DB_NAME}"
export POSTGRES_PORT="${DB_PORT}"
EOF

    echo "PostgreSQL setup complete!"
    echo "Database: ${DB_NAME}"
    echo "User: ${DB_USER}"
    echo "Port: ${DB_PORT}"
    echo ""
fi

echo "Environment variables saved to db_visualizer/postgres.env"
echo "To use with Node.js viewer, run: source db_visualizer/postgres.env"

echo "To connect to the database, use one of the following commands:"
echo "psql -h localhost -U ${DB_USER} -d ${DB_NAME} -p ${DB_PORT}"
if [ -f "db_connection.txt" ]; then
  echo "$(cat db_connection.txt)"
fi

# -----------------------------------------------------------------------------
# Idempotent schema migrations using DSN from db_connection.txt
# Each statement is executed individually via psql -c
# -----------------------------------------------------------------------------

echo ""
echo "Applying database schema migrations (idempotent)..."

# Ensure db_connection.txt exists; if missing (e.g., server already running), create it
if [ ! -f "db_connection.txt" ]; then
  echo "db_connection.txt not found; creating from environment variables..."
  echo "psql postgresql://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}" > db_connection.txt
fi

# Read the full psql command (must start with 'psql postgresql://...')
PSQL_CMD="$(cat db_connection.txt | tr -d '\r')"

# Quick connectivity check
$PSQL_CMD -c "SELECT 1;" >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "⚠ Failed to connect using db_connection.txt; please verify DSN and server status."
else
  echo "✓ Connection verified; running migrations..."

  run_sql() {
    local sql="$1"
    echo "  -> $sql"
    # Execute each SQL statement individually via psql -c
    $PSQL_CMD -v ON_ERROR_STOP=1 -c "$sql" >/dev/null
    if [ $? -ne 0 ]; then
      echo "     ✗ Failed: $sql"
      return 1
    else
      echo "     ✓ Done"
      return 0
    fi
  }

  # NOTE: Avoid extensions to keep non-superuser compatibility.
  # UUID defaults and CITEXT are intentionally not used to allow running as appuser.
  # The backend should provide UUID values on insert.

  # organizations table
  run_sql "CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )"

  # organizations indexes
  run_sql "CREATE UNIQUE INDEX IF NOT EXISTS organizations_name_lower_uq ON organizations ((lower(name)))"
  run_sql "CREATE UNIQUE INDEX IF NOT EXISTS organizations_slug_lower_uq ON organizations ((lower(slug))) WHERE slug IS NOT NULL"

  # users table
  run_sql "CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'user',
    password_hash TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT users_role_chk CHECK (role IN ('admin','user','readonly'))
  )"

  # users indexes and constraints
  run_sql "CREATE UNIQUE INDEX IF NOT EXISTS users_org_email_lower_uq ON users (organization_id, lower(email))"
  run_sql "CREATE INDEX IF NOT EXISTS users_org_idx ON users (organization_id)"
  run_sql "CREATE INDEX IF NOT EXISTS users_role_idx ON users (role)"

  # resources table
  run_sql "CREATE TABLE IF NOT EXISTS resources (
    id UUID PRIMARY KEY,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    type TEXT NOT NULL,
    name TEXT NOT NULL,
    tags JSONB NOT NULL DEFAULT '{}'::jsonb,
    cost NUMERIC(14,2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT resources_provider_chk CHECK (provider IN ('AWS','Azure','GCP')),
    CONSTRAINT resources_status_chk CHECK (status IN ('active','inactive','deleted'))
  )"

  # resources indexes
  run_sql "CREATE UNIQUE INDEX IF NOT EXISTS resources_org_provider_type_name_uq ON resources (organization_id, provider, type, name)"
  run_sql "CREATE INDEX IF NOT EXISTS resources_org_idx ON resources (organization_id)"
  run_sql "CREATE INDEX IF NOT EXISTS resources_provider_idx ON resources (provider)"
  run_sql "CREATE INDEX IF NOT EXISTS resources_status_idx ON resources (status)"
  run_sql "CREATE INDEX IF NOT EXISTS resources_tags_gin_idx ON resources USING GIN (tags)"

  echo "✓ Schema migrations complete."
fi

# -----------------------------------------------------------------------------
# Optional db_visualizer startup (DISABLED by default)
# Set DB_VISUALIZER_ENABLED=true in the environment prior to running this script
# to auto-install dependencies and start the viewer in the background.
# -----------------------------------------------------------------------------
if [ "${DB_VISUALIZER_ENABLED:-false}" = "true" ]; then
    echo ""
    echo "[db_visualizer] DB_VISUALIZER_ENABLED=true -> preparing to start viewer..."
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        cd db_visualizer || {
            echo "[db_visualizer] Could not cd into db_visualizer directory"; 
            exit 0; 
        }

        # Load postgres.env if present for convenience
        if [ -f "postgres.env" ]; then
            set -a
            # shellcheck disable=SC1091
            . ./postgres.env
            set +a
        fi

        # Install dependencies if express is missing or node_modules is absent
        if [ ! -d "node_modules" ] || [ ! -f "node_modules/express/package.json" ]; then
            echo "[db_visualizer] Installing dependencies (omit dev)..."
            npm install --omit=dev --no-audit --no-fund --silent || {
                echo "[db_visualizer] npm install failed; viewer will not be started."
                exit 0
            }
        fi

        # Start viewer in the background, bind to all interfaces
        mkdir -p ../logs
        echo "[db_visualizer] Starting viewer on 0.0.0.0:${PORT:-3000} ..."
        nohup node server.js --host 0.0.0.0 > ../logs/db_visualizer.log 2>&1 &
        echo "[db_visualizer] Started. Logs: Database/logs/db_visualizer.log"
    else
        echo "[db_visualizer] Node.js and npm not found; skipping viewer startup."
    fi
else
    echo ""
    echo "[db_visualizer] Viewer is disabled by default. To enable set DB_VISUALIZER_ENABLED=true"
    echo "[db_visualizer] Then re-run this script, or start manually:"
    echo "    cd cloudunify-pro-284073-286484/Database/db_visualizer"
    echo "    npm install --omit=dev"
    echo "    node server.js --host 0.0.0.0"
fi
