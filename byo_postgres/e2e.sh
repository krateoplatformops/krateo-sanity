#!/usr/bin/env bash
# ==============================================================================
# e2e.sh - Bring Your Own PostgreSQL end-to-end test
# ==============================================================================
# Validates the guide:
#   krateo-v2-docs/docs/30-how-to-guides/50-manage-postgresql/
#     40-bring-your-own-postgresql.md
#
# Flow: dedicated kind cluster -> external PostgreSQL -> provision DB/role
#       (verbatim guide SQL) -> krateo-db secret + custom profile ->
#       `krateoctl install apply --profile no-cnpg,custom-cnpg-profile` ->
#       verify (no CNPG, components Ready, deviser schema in the external DB).
#
# The cluster is torn down on exit unless BYO_KEEP_CLUSTER=true.
# ==============================================================================
set -euo pipefail
BYO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${BYO_DIR}/lib.sh"

byo_require_tools

if [ -z "${KRATEO_VERSION}" ]; then
    die "KRATEO_VERSION is required.
     Pin a Krateo release whose bundled deviser uses native gen_random_uuid()
     (no pgcrypto); see byo_postgres.conf for why. Example:
       KRATEO_VERSION=3.0.0 ./e2e.sh"
fi

teardown() {
    local rc=$?
    if [ "${BYO_KEEP_CLUSTER}" = "true" ]; then
        log_warn "BYO_KEEP_CLUSTER=true -> leaving cluster '${BYO_CLUSTER_NAME}' up"
        log_info "Inspect with: KUBECONFIG=${KUBECONFIG} kubectl get pods -A"
    else
        log_info "Tearing down kind cluster '${BYO_CLUSTER_NAME}'"
        kind delete cluster --name "${BYO_CLUSTER_NAME}" >/dev/null 2>&1 || true
        rm -rf "${BYO_RUN_DIR}" || true
    fi
    if [ "${rc}" -eq 0 ]; then
        log_success "e2e finished successfully"
    else
        log_error "e2e failed (exit ${rc})"
    fi
}
trap teardown EXIT

run_step() {
    local script="$1"
    echo ""
    log_info "==> ${script##*/}"
    bash "${script}"
}

run_step "${BYO_DIR}/steps/00_kind_up.sh"
run_step "${BYO_DIR}/steps/10_external_postgres.sh"
run_step "${BYO_DIR}/steps/20_provision_db.sh"
run_step "${BYO_DIR}/steps/30_secret_and_profile.sh"
run_step "${BYO_DIR}/steps/40_install_krateo.sh"
run_step "${BYO_DIR}/steps/50_verify.sh"
