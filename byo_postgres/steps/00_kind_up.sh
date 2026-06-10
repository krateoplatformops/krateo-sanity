#!/usr/bin/env bash
# Step 00: create a dedicated, ephemeral kind cluster on an isolated kubeconfig.
set -euo pipefail
STEP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib.sh
source "${STEP_DIR}/../lib.sh"

byo_require_tools

if kind get clusters 2>/dev/null | grep -qx "${BYO_CLUSTER_NAME}"; then
    log_info "kind cluster '${BYO_CLUSTER_NAME}' already exists; reusing it"
else
    log_info "Creating kind cluster '${BYO_CLUSTER_NAME}' (image ${BYO_CLUSTER_IMAGE})"
    # No host port mappings are needed: every assertion runs in-cluster
    # (kubectl/exec), which keeps the test free of host-port conflicts.
    kind create cluster \
        --name "${BYO_CLUSTER_NAME}" \
        --image "${BYO_CLUSTER_IMAGE}" \
        --kubeconfig "${KUBECONFIG}" \
        --wait 120s \
        || die "failed to create kind cluster"
fi

# Make sure our isolated kubeconfig points at this cluster.
kubectl config use-context "$(byo_kube_context)" >/dev/null 2>&1 || true
check_kubectl_context
kubectl get nodes || die "cluster not reachable"
log_success "kind cluster ready"
