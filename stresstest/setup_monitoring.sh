#!/bin/bash

# ==============================================================================
# setup_monitoring.sh - Install Prometheus/Grafana monitoring stack
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh" || { echo "Error: common.sh not found"; exit 1; }
source "$SCRIPT_DIR/../config/stresstest.conf" || { echo "Error: stresstest.conf not found"; exit 1; }

init_common
check_kubectl_context

log_info "Setting up Prometheus/Grafana monitoring stack..."

# Confirm action
if ! confirm_action "Install monitoring stack on current cluster?"; then
    log_warn "Aborted by user"
    exit 0
fi

# Create monitoring namespace
create_namespace_safe "$MONITORING_NAMESPACE"

# Add Prometheus Community Helm repository
add_helm_repo "prometheus-community" "$PROMETHEUS_REPO_URL"

# Install kube-prometheus-stack
helm_install_or_upgrade "prometheus-stack" "prometheus-community/kube-prometheus-stack" \
    "$MONITORING_NAMESPACE" \
    "--wait" \
    '--set' "grafana.adminPassword=$GRAFANA_ADMIN_PASSWORD" \
    '--set' "prometheus.retention=30d"

log_success "Monitoring stack installed!"

# Get Grafana service name
GRAFANA_SERVICE_NAME=$(kubectl get svc -n "$MONITORING_NAMESPACE" \
    -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)

if [ -n "$GRAFANA_SERVICE_NAME" ]; then
    echo ""
    log_info "To access Grafana, run:"
    echo "  kubectl port-forward -n $MONITORING_NAMESPACE svc/$GRAFANA_SERVICE_NAME $GRAFANA_PORT:80"
    echo ""
    log_info "Credentials: admin / $GRAFANA_ADMIN_PASSWORD"
else
    log_warn "Could not determine Grafana service name"
fi
