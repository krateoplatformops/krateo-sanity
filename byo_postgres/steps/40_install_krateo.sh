#!/usr/bin/env bash
# Step 40: install Krateo without CNPG, pointing at the external PostgreSQL.
set -euo pipefail
STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib.sh
source "${STEP_DIR}/../lib.sh"

[ -n "${KRATEO_VERSION}" ] || die "KRATEO_VERSION is required (see byo_postgres.conf)"
[ -f "${BYO_RENDERED_PROFILE}" ] || die "rendered profile missing; run step 30 first"

profiles="$(byo_profiles)"

# Optional: preload a custom deviser image into the cluster so it is used
# regardless of registry visibility or node architecture.
if byo_deviser_override_enabled && [ "${DEVISER_KIND_LOAD}" = "true" ]; then
    img="${DEVISER_IMAGE_REPOSITORY}:${DEVISER_IMAGE_TAG}"
    log_info "Loading deviser image '${img}' into kind cluster '${BYO_CLUSTER_NAME}'"
    kind load docker-image "${img}" --name "${BYO_CLUSTER_NAME}" \
        || die "failed to kind-load ${img} (is it present in local Docker?)"
fi

log_info "Installing Krateo ${KRATEO_VERSION} with profiles: ${profiles}"

# krateoctl resolves a *local* profile file from the current working directory
# (it looks for krateo-overrides.<profile>.yaml next to the default
# krateo-overrides.yaml path). The rendered profile already lives in
# $BYO_RUN_DIR with exactly that name, so run krateoctl from there.
(
    cd "${BYO_RUN_DIR}"
    byo_krateoctl install apply \
        --version "${KRATEO_VERSION}" \
        --namespace "${KRATEO_SYSTEM_NAMESPACE}" \
        --profile "${profiles}" \
        --init-secrets
) || die "krateoctl install apply failed"

log_success "krateoctl install apply completed"
