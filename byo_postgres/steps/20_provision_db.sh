#!/usr/bin/env bash
# Step 20: provision the Krateo database + role using the EXACT SQL from the
# guide (step 1). This is the behaviour under test, so the statements are kept
# verbatim; only the password is injected from config.
set -euo pipefail
STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib.sh
source "${STEP_DIR}/../lib.sh"

# Idempotency guard at the step level (so the step can be re-run) WITHOUT
# altering the guide's SQL: only provision if the database is absent.
existing="$(byo_psql_scalar postgres \
    "SELECT 1 FROM pg_database WHERE datname = '${KRATEO_DB_NAME}'" | tr -d '[:space:]')"
if [ "${existing}" = "1" ]; then
    log_info "Database '${KRATEO_DB_NAME}' already exists; skipping provisioning"
    exit 0
fi

log_info "Provisioning role '${KRATEO_DB_USER}' and database '${KRATEO_DB_NAME}' (guide step 1)"

# Verbatim guide SQL:
#   CREATE USER "krateo-db-user" WITH ENCRYPTED PASSWORD 'your_password';
#   CREATE DATABASE "krateo-db" OWNER "krateo-db-user";
byo_psql_super postgres <<SQL || die "provisioning failed"
CREATE USER "${KRATEO_DB_USER}" WITH ENCRYPTED PASSWORD '${KRATEO_DB_PASS}';
CREATE DATABASE "${KRATEO_DB_NAME}" OWNER "${KRATEO_DB_USER}";
SQL

log_success "Database and owner role created per the guide"
