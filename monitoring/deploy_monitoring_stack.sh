#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

# =========================
# Bootstrap
# =========================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"    || { echo "Error: utils/common.sh not found"; exit 1; }
source "$SCRIPT_DIR/../config/common.conf" || { echo "Error: config/common.conf not found"; exit 1; }

# =========================
# Config
# =========================
NAMESPACE="monitoring"
OTEL_RELEASE="otel-collector"
PROM_RELEASE="kube-prom"
OTEL_REPO_URL="https://open-telemetry.github.io/opentelemetry-helm-charts"

# PROMETHEUS_REPO_URL is sourced from config/common.conf
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"

OTEL_VALUES_FILE="otelcol-values.yaml"
PROM_VALUES_FILE="kube-prom-values.yaml"

# =========================
# Error trap
# =========================
trap 'log_error "Script failed at line $LINENO"' ERR

# =========================
# Pre-flight checks
# =========================
check_prerequisites() {
  log_info "Checking prerequisites..."

  init_common          # checks kubectl, helm, jq; registers INT trap
  check_kubectl_context

  kubectl cluster-info >/dev/null 2>&1 || die "kubectl is not connected to a cluster"

  log_success "All prerequisites satisfied"
}

# =========================
# Helm setup
# =========================
setup_helm_repos() {
  add_helm_repo "open-telemetry"       "$OTEL_REPO_URL"
  add_helm_repo "prometheus-community" "$PROMETHEUS_REPO_URL"
}

# =========================
# Generate values files
# =========================
generate_otel_values() {
  log_info "Generating $OTEL_VALUES_FILE"

  cat > "$OTEL_VALUES_FILE" <<'EOF'
mode: deployment

image:
  repository: "otel/opentelemetry-collector-contrib"

config:
  receivers:
    otlp:
      protocols:
        http:
          endpoint: 0.0.0.0:4318
  processors:
    batch: {}
  exporters:
    prometheus:
      endpoint: 0.0.0.0:9464
  service:
    pipelines:
      metrics:
        receivers: [otlp]
        processors: [batch]
        exporters: [prometheus]

ports:
  otlp-http:
    enabled: true
    containerPort: 4318
    servicePort: 4318
    protocol: TCP
  prom-metrics:
    enabled: true
    containerPort: 9464
    servicePort: 9464
    protocol: TCP
EOF
}

generate_prom_values() {
  log_info "Generating $PROM_VALUES_FILE"

  cat > "$PROM_VALUES_FILE" <<'EOF'
grafana:
  enabled: true

prometheus:
  prometheusSpec:
    scrapeInterval: 15s
    retention: 30d
    additionalScrapeConfigs:
      - job_name: "otel-collector"
        static_configs:
          - targets: ["otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:9464"]

alertmanager:
  enabled: false

nodeExporter:
  enabled: false

kubeStateMetrics:
  enabled: false
EOF
}

# =========================
# Deploy components
# =========================
deploy_otel() {
  helm_install_or_upgrade "$OTEL_RELEASE" "open-telemetry/opentelemetry-collector" "$NAMESPACE" \
    --wait --timeout 10m \
    -f "$OTEL_VALUES_FILE"
}

deploy_prometheus() {
  helm_install_or_upgrade "$PROM_RELEASE" "prometheus-community/kube-prometheus-stack" "$NAMESPACE" \
    --wait --timeout 10m \
    -f "$PROM_VALUES_FILE" \
    --set "grafana.adminPassword=${GRAFANA_ADMIN_PASSWORD}"
}

# =========================
# Verification
# =========================
verify_deployment() {
  log_info "Verifying deployment..."

  kubectl get pods -n "$NAMESPACE"
  kubectl get svc  -n "$NAMESPACE"

  log_success "Deployment verified"
}

# =========================
# Access info
# =========================
print_access_info() {
  local grafana_svc
  grafana_svc=$(kubectl get svc -n "$NAMESPACE" \
    -l app.kubernetes.io/name=grafana \
    -o jsonpath="{.items[0].metadata.name}" 2>/dev/null) || grafana_svc=""

  cat <<EOF

========================================
Access your monitoring stack:

Prometheus:
  kubectl port-forward svc/${PROM_RELEASE}-kube-prometheus-prometheus -n ${NAMESPACE} 9090:9090
  -> http://localhost:9090

Grafana:
  kubectl port-forward svc/${grafana_svc:-${PROM_RELEASE}-grafana} -n ${NAMESPACE} ${GRAFANA_PORT}:80
  -> http://localhost:${GRAFANA_PORT}
  -> username: admin
  -> password: ${GRAFANA_ADMIN_PASSWORD}
========================================

EOF
}

# =========================
# Main
# =========================
main() {
  check_prerequisites

  if ! confirm_action "Deploy monitoring stack on current cluster?"; then
    log_warn "Aborted by user"
    exit 0
  fi

  setup_helm_repos
  create_namespace_safe "$NAMESPACE"

  generate_otel_values
  generate_prom_values

  deploy_otel
  deploy_prometheus

  verify_deployment
  print_access_info
}

main "$@"
