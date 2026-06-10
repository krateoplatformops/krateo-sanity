#!/usr/bin/env bash
# Step 30: pre-create the krateo-db secret and render the custom profile.
#
# Pre-creating the secret is the key seam for BYO: `krateoctl ... --init-secrets`
# is skip-if-exists, so it will NOT overwrite our secret -- it only fills in the
# remaining (jwt-sign-key, and the unused krateo-db-user) secrets.
set -euo pipefail
STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib.sh
source "${STEP_DIR}/../lib.sh"

create_namespace_safe "${KRATEO_SYSTEM_NAMESPACE}"

log_info "Creating/updating secret 'krateo-db' in '${KRATEO_SYSTEM_NAMESPACE}'"
# DB_USER must match the owner role created in step 20.
kubectl create secret generic krateo-db \
    --namespace "${KRATEO_SYSTEM_NAMESPACE}" \
    --from-literal=DB_USER="${KRATEO_DB_USER}" \
    --from-literal=DB_PASS="${KRATEO_DB_PASS}" \
    --dry-run=client -o yaml | kubectl apply -f - \
    || die "failed to create krateo-db secret"

log_info "Rendering custom profile -> ${BYO_RENDERED_PROFILE}"
byo_render \
    "${BYO_DIR}/manifests/krateo-overrides.${BYO_PROFILE_NAME}.yaml" \
    "${BYO_RENDERED_PROFILE}"

if byo_deviser_override_enabled; then
    log_info "Rendering deviser-image profile (${DEVISER_IMAGE_REPOSITORY}:${DEVISER_IMAGE_TAG})"
    byo_render \
        "${BYO_DIR}/manifests/krateo-overrides.${BYO_DEVISER_PROFILE_NAME}.yaml" \
        "${BYO_RENDERED_DEVISER_PROFILE}"
fi

log_success "Secret and profile ready (DB_HOST=${BYO_DB_HOST})"
