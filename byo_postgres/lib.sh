#!/usr/bin/env bash
# ==============================================================================
# lib.sh - shared setup + helpers for the BYO PostgreSQL e2e
# ==============================================================================
# Sourced by every step and by e2e.sh. It:
#   - loads the repo-wide helpers (utils/common.sh) and this test's config,
#   - isolates the test on a dedicated KUBECONFIG so it can never touch the
#     user's current cluster/context,
#   - exposes BYO-specific helpers (template rendering, psql, assertions).
# ==============================================================================

# Resolve this folder regardless of where the caller runs from.
BYO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BYO_DIR

# Repo-wide helpers (logging, kubectl/helm wrappers, etc.).
# shellcheck source=../utils/common.sh
source "${BYO_DIR}/../utils/common.sh" || { echo "Error: utils/common.sh not found"; exit 1; }

# Test configuration.
# shellcheck source=./byo_postgres.conf
source "${BYO_DIR}/byo_postgres.conf" || die "byo_postgres.conf not found"

# --- isolation ----------------------------------------------------------------
# All kubectl / helm / krateoctl calls in this test honor $KUBECONFIG, so a
# dedicated file keeps the test entirely separate from the user's clusters.
export BYO_RUN_DIR="${BYO_DIR}/.run"
mkdir -p "${BYO_RUN_DIR}"
export KUBECONFIG="${BYO_RUN_DIR}/kubeconfig"

# krateoctl resolves KUBECONFIG as a path RELATIVE TO $HOME
# (internal/util/kube/config.go: filepath.Join(home, $KUBECONFIG)) -- unlike
# kubectl/helm/kind, which treat it as absolute. So for krateoctl we must pass
# the kubeconfig path relative to $HOME. This requires the run dir to live under
# $HOME, which it does (the repo is under the user's home).
case "${KUBECONFIG}" in
    "${HOME}/"*) export BYO_KUBECONFIG_REL="${KUBECONFIG#"${HOME}"/}" ;;
    *) BYO_KUBECONFIG_REL="" ;;
esac

# Run krateoctl with the $HOME-relative KUBECONFIG so it targets our isolated
# cluster instead of falling back to in-cluster config. Falls back to the
# absolute value if the run dir is not under $HOME (krateoctl may then misbehave).
byo_krateoctl() {
    if [ -n "${BYO_KUBECONFIG_REL}" ]; then
        KUBECONFIG="${BYO_KUBECONFIG_REL}" krateoctl "$@"
    else
        log_warn "run dir is not under \$HOME; krateoctl may not find the kubeconfig"
        krateoctl "$@"
    fi
}

# Derived values.
export BYO_DB_HOST="${EXTERNAL_DB_NAME}.${EXTERNAL_DB_NAMESPACE}.svc.cluster.local"
export BYO_RENDERED_PROFILE="${BYO_RUN_DIR}/krateo-overrides.${BYO_PROFILE_NAME}.yaml"
export BYO_RENDERED_DEVISER_PROFILE="${BYO_RUN_DIR}/krateo-overrides.${BYO_DEVISER_PROFILE_NAME}.yaml"
export BYO_RENDERED_POSTGRES="${BYO_RUN_DIR}/postgres.yaml"

# --- prerequisites ------------------------------------------------------------
byo_require_tools() {
    check_command "kind"
    check_command "kubectl"
    check_command "helm"
    check_command "jq"
    check_command "krateoctl"
}

# --- template rendering -------------------------------------------------------
# Renders a manifests/ template into $BYO_RUN_DIR by substituting @@TOKENS@@.
# Tokens are used (instead of ${VAR}) so they never collide with shell or YAML.
# Usage: byo_render <src-template> <dst-file>
byo_render() {
    local src="$1" dst="$2"
    [ -f "$src" ] || die "template not found: $src"
    sed \
        -e "s|@@EXTERNAL_DB_NAMESPACE@@|${EXTERNAL_DB_NAMESPACE}|g" \
        -e "s|@@EXTERNAL_DB_NAME@@|${EXTERNAL_DB_NAME}|g" \
        -e "s|@@POSTGRES_IMAGE@@|${POSTGRES_IMAGE}|g" \
        -e "s|@@POSTGRES_SUPERUSER@@|${POSTGRES_SUPERUSER}|g" \
        -e "s|@@POSTGRES_SUPERUSER_PASSWORD@@|${POSTGRES_SUPERUSER_PASSWORD}|g" \
        -e "s|@@DB_HOST@@|${BYO_DB_HOST}|g" \
        -e "s|@@DB_PORT@@|${KRATEO_DB_PORT}|g" \
        -e "s|@@KRATEO_DB_NAME@@|${KRATEO_DB_NAME}|g" \
        -e "s|@@DEVISER_IMAGE_REPOSITORY@@|${DEVISER_IMAGE_REPOSITORY}|g" \
        -e "s|@@DEVISER_IMAGE_TAG@@|${DEVISER_IMAGE_TAG}|g" \
        -e "s|@@DEVISER_IMAGE_PULL_POLICY@@|${DEVISER_IMAGE_PULL_POLICY}|g" \
        "$src" > "$dst" || die "failed to render $src"
}

# True when a custom deviser image was requested.
byo_deviser_override_enabled() { [ -n "${DEVISER_IMAGE_REPOSITORY}" ]; }

# The comma-separated profile list for `krateoctl install apply`. The optional
# deviser-image profile is appended last so it overrides the image only.
byo_profiles() {
    local p="no-cnpg,${BYO_PROFILE_NAME}"
    if byo_deviser_override_enabled; then
        p="${p},${BYO_DEVISER_PROFILE_NAME}"
    fi
    echo "${p}"
}

# --- psql against the external PostgreSQL -------------------------------------
# Runs SQL read from stdin as the superuser, stopping on the first error.
# Usage: byo_psql_super <database>   (SQL on stdin)
byo_psql_super() {
    local db="$1"
    kubectl exec -i -n "${EXTERNAL_DB_NAMESPACE}" "deployment/${EXTERNAL_DB_NAME}" -- \
        psql -U "${POSTGRES_SUPERUSER}" -d "${db}" -v ON_ERROR_STOP=1
}

# Returns a single scalar from a query (tuples-only, unaligned).
# Usage: byo_psql_scalar <database> "<sql>"
byo_psql_scalar() {
    local db="$1" sql="$2"
    kubectl exec -i -n "${EXTERNAL_DB_NAMESPACE}" "deployment/${EXTERNAL_DB_NAME}" -- \
        psql -U "${POSTGRES_SUPERUSER}" -d "${db}" -tAc "${sql}"
}

# --- misc ---------------------------------------------------------------------
# The kind context name created for $BYO_CLUSTER_NAME.
byo_kube_context() { echo "kind-${BYO_CLUSTER_NAME}"; }
