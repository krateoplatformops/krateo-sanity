#!/bin/bash

# ==============================================================================
# stresstest_setup.sh - Setup Krateo dependencies for stress testing
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh" || { echo "Error: common.sh not found"; exit 1; }
source "$SCRIPT_DIR/../config/stresstest.conf" || { echo "Error: stresstest.conf not found"; exit 1; }

init_common

log_info "Starting Krateo stress test environment setup..."

# Create stress test namespace
create_namespace_safe "$STRESSTEST_NAMESPACE"

# Install metrics server (in kube-system namespace)
log_info "Installing Kubernetes metrics server..."
kubectl apply -f "$METRICS_SERVER_URL" || die "Failed to install metrics server"

# Patch metrics server to use insecure TLS (for local testing)
kubectl patch -n "$KUBE_SYSTEM_NAMESPACE" deployment metrics-server \
    --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' 2>/dev/null || \
    log_warn "Could not patch metrics server (may already be patched)"

# TODO: Add check to verify metrics server is up and running before proceeding

log_success "Metrics server installed"

log_success "Krateo stress test environment setup completed!"