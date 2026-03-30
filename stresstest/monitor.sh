#!/bin/bash

# ==============================================================================
# monitor.sh - Monitor memory usage of Krateo pods
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh" || { echo "Error: common.sh not found"; exit 1; }
source "$SCRIPT_DIR/../config/stresstest.conf" || { echo "Error: stresstest.conf not found"; exit 1; }

init_common

# Calculate number of iterations
ITERATIONS=$((MONITORING_DURATION_MINUTES * 60 / MONITORING_INTERVAL))
TIMESTAMP_SUFFIX=$(date +%Y%m%d_%H%M%S)
LOG_FILE="stresstest/${MONITORING_LOG_PREFIX}_${TIMESTAMP_SUFFIX}.log"

log_info "Starting memory usage monitoring for ${MONITORING_DURATION_MINUTES} minutes (Snapshot every ${MONITORING_INTERVAL}s)"
log_info "Results will be saved to: $LOG_FILE"

# Write CSV header to log file
echo "TIMESTAMP,POD_NAME,MEMORY_USAGE_Mi" > "$LOG_FILE"

# Monitor loop
for ((i=1; i<=ITERATIONS; i++)); do
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Get memory usage for all pods in the namespace
    kubectl top pod --namespace "$STRESSTEST_NAMESPACE" --no-headers 2>/dev/null | 
    awk -v timestamp="$TIMESTAMP" '
        {
            # Get the usage value and unit
            usage = $2
            unit = substr(usage, length(usage)-1)
            val = substr(usage, 1, length(usage)-2)
            
            # Standardize to MiB
            if (unit == "Gi") {
                mib_val = val * 1024
            } else if (unit == "Mi") {
                mib_val = val
            } else if (unit ~ /B/) {
                mib_val = substr(usage, 1, length(usage)-1) / 1024 / 1024
            } else {
                mib_val = usage
            }
            
            printf "%s,%s,%.2f\n", timestamp, $1, mib_val
        }' >> "$LOG_FILE"
    
    log_info "Snapshot $i/$ITERATIONS taken. Sleeping for ${MONITORING_INTERVAL}s..."
    sleep "$MONITORING_INTERVAL"
done

log_success "Memory monitoring completed! Data saved to: $LOG_FILE"