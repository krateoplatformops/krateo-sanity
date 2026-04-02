#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

# ==============================================================================
# monitor.sh - Monitor memory usage of Krateo pods
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../utils/common.sh" || { echo "Error: common.sh not found"; exit 1; }
source "$SCRIPT_DIR/../config/stresstest.conf" || { echo "Error: stresstest.conf not found"; exit 1; }

init_common

# =========================
# Arguments
# =========================
if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <namespace>" >&2
  exit 1
fi
NAMESPACE="$1"

# =========================
# Pre-flight checks
# =========================
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] Required command not found: $1" >&2
    exit 1
  }
}

require_cmd kubectl
require_cmd awk

# Validate config
: "${MONITORING_DURATION_MINUTES:?Missing MONITORING_DURATION_MINUTES}"
: "${MONITORING_INTERVAL:?Missing MONITORING_INTERVAL}"
: "${STRESSTEST_NAMESPACE:?Missing STRESSTEST_NAMESPACE}"
: "${MONITORING_LOG_PREFIX:?Missing MONITORING_LOG_PREFIX}"

# =========================
# Setup paths
# =========================
ITERATIONS=$((MONITORING_DURATION_MINUTES * 60 / MONITORING_INTERVAL))
TIMESTAMP_SUFFIX="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="stresstest/logs/${MONITORING_LOG_PREFIX}_${TIMESTAMP_SUFFIX}.log"

mkdir -p "$(dirname "$LOG_FILE")"

log_info "Starting memory usage monitoring for ${MONITORING_DURATION_MINUTES} minutes (every ${MONITORING_INTERVAL}s)"
log_info "Results will be saved to: $LOG_FILE"

# =========================
# Verify metrics-server availability
# =========================
if ! kubectl top pod -n "$STRESSTEST_NAMESPACE" >/dev/null 2>&1; then
  log_error "kubectl top pod failed. Is metrics-server installed and working?"
  exit 1
fi

# =========================
# Initialize log file
# =========================
printf "TIMESTAMP,POD_NAME,MEMORY_USAGE_Mi\n" > "$LOG_FILE"

# =========================
# Monitoring loop (drift-safe)
# =========================
start_time=$(date +%s)

for ((i=1; i<=ITERATIONS; i++)); do
    iteration_start=$(date +%s)
    timestamp="$(date "+%Y-%m-%d %H:%M:%S")"

    top_output=$(kubectl top pod --namespace "$NAMESPACE" --no-headers 2>/dev/null) || true

    if [[ -z "$top_output" ]]; then
        log_warn "No pods found in namespace '$1' at snapshot $i/$ITERATIONS — skipping"
    else
        if ! printf '%s\n' "$top_output" | \
            awk -v timestamp="$timestamp" '
            {
                usage = $3
                unit = substr(usage, length(usage)-1)
                val = substr(usage, 1, length(usage)-2)

                if (unit == "Gi") {
                    mib_val = val * 1024
                } else if (unit == "Mi") {
                    mib_val = val
                } else if (unit == "Ki") {
                    mib_val = val / 1024
                } else if (unit ~ /B/) {
                    mib_val = substr(usage, 1, length(usage)-1) / 1024 / 1024
                } else {
                    mib_val = usage
                }

                printf "%s,%s,%.2f\n", timestamp, $1, mib_val
            }' >> "$LOG_FILE"; then
            log_error "Failed to collect metrics at iteration $i"
        fi

        log_info "Snapshot $i/$ITERATIONS recorded"
    fi

    # =========================
    # Drift-free sleep
    # =========================
    elapsed=$(( $(date +%s) - iteration_start ))
    sleep_time=$(( MONITORING_INTERVAL - elapsed ))

    if (( sleep_time > 0 )); then
        sleep "$sleep_time"
    fi
done

log_success "Memory monitoring completed! Data saved to: $LOG_FILE"