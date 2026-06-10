#!/usr/bin/env bash
# Step 10: deploy the external ("bring your own") PostgreSQL instance.
set -euo pipefail
STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib.sh
source "${STEP_DIR}/../lib.sh"

log_info "Rendering external PostgreSQL manifest"
byo_render "${BYO_DIR}/manifests/postgres.yaml" "${BYO_RENDERED_POSTGRES}"

log_info "Applying external PostgreSQL (namespace '${EXTERNAL_DB_NAMESPACE}')"
kubectl apply -f "${BYO_RENDERED_POSTGRES}" || die "failed to apply postgres manifest"

wait_for_deployment "${EXTERNAL_DB_NAMESPACE}" "${EXTERNAL_DB_NAME}" "${BYO_DB_TIMEOUT}"

# Belt-and-suspenders: wait until the server actually accepts connections.
log_info "Waiting for PostgreSQL to accept connections"
for ((i = 1; i <= 30; i++)); do
    if kubectl exec -n "${EXTERNAL_DB_NAMESPACE}" "deployment/${EXTERNAL_DB_NAME}" -- \
        pg_isready -U "${POSTGRES_SUPERUSER}" -d postgres >/dev/null 2>&1; then
        log_success "PostgreSQL is accepting connections"
        exit 0
    fi
    sleep 2
done
die "PostgreSQL did not become ready in time"
