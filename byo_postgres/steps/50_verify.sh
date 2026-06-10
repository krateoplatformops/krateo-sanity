#!/usr/bin/env bash
# Step 50: verify the BYO install actually works end-to-end.
#
# Three independent proofs:
#   A. CNPG was NOT installed (the no-cnpg profile took effect).
#   B. Every DB-dependent component became Ready against the external DB.
#   C. deviser bootstrapped the schema in the external DB exactly as the guide
#      promises -- using native gen_random_uuid(), with no pgcrypto.
set -euo pipefail
STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib.sh
source "${STEP_DIR}/../lib.sh"

ns="${KRATEO_SYSTEM_NAMESPACE}"

# --- A. No CNPG ---------------------------------------------------------------
log_info "A. Asserting CNPG was not installed"
if kubectl get svc pg-cluster-rw -n "${ns}" >/dev/null 2>&1; then
    die "found CNPG service 'pg-cluster-rw' in ${ns}: no-cnpg profile did not take effect"
fi
# The CNPG Cluster CRD should not even be present; if it is, ensure no Cluster exists.
if kubectl get crd clusters.postgresql.cnpg.io >/dev/null 2>&1; then
    found="$(kubectl get clusters.postgresql.cnpg.io -A --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')"
    [ "${found}" = "0" ] || die "found ${found} CNPG Cluster object(s); expected none"
fi
log_success "A. No CNPG resources present"

# --- B. DB-dependent components Ready ----------------------------------------
log_info "B. Waiting for DB-dependent components to be Ready"
for dep in deviser resources-ingester resources-presenter events-ingester events-presenter; do
    wait_for_deployment "${ns}" "${dep}" "${BYO_INSTALL_COMPONENT_TIMEOUT}"
done
log_success "B. All DB-dependent components are Ready"

# Diagnostic only (not asserted): a few lines of deviser's log.
log_info "deviser log tail (diagnostic):"
kubectl logs -n "${ns}" deployment/deviser --tail=15 2>/dev/null | sed 's/^/    /' || true

# --- C. Schema bootstrapped by deviser in the external DB --------------------
log_info "C. Asserting deviser schema in '${KRATEO_DB_NAME}' (no pgcrypto, native UUID)"
byo_psql_super "${KRATEO_DB_NAME}" <<'SQL' || die "schema verification failed"
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'krateo_resources'
  ) THEN
    RAISE EXCEPTION 'missing table krateo_resources';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'k8s_events'
      AND column_name = 'event_id'
      AND is_nullable = 'NO'
  ) THEN
    RAISE EXCEPTION 'missing NOT NULL k8s_events.event_id column';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM schema_migrations
    WHERE version = '001_k8s_events_event_id'
  ) THEN
    RAISE EXCEPTION 'missing schema_migrations record for 001_k8s_events_event_id';
  END IF;

  IF pg_get_functiondef('notify_new_event'::regproc)
       NOT LIKE '%json_build_object%event_id%global_uid%' THEN
    RAISE EXCEPTION 'notify_new_event does not publish JSON event_id/global_uid payload';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
    RAISE EXCEPTION 'pgcrypto is installed; BYO setup must not require any extension';
  END IF;
END $$;
SQL
log_success "C. Schema verified: tables, event_id, migration, trigger payload, no pgcrypto"

echo ""
log_success "✅ BYO PostgreSQL e2e PASSED"
