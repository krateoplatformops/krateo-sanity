#!/bin/bash

# ==============================================================================
# stresstest_composition_status.sh - Check Krateo resource status
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh" || { echo "Error: common.sh not found"; exit 1; }
source "$SCRIPT_DIR/../config/stresstest.conf" || { echo "Error: stresstest.conf not found"; exit 1; }

init_common

log_info "Checking Krateo resource status..."
log_info "API Group: $STRESSTEST_API_GROUP"
log_info "Namespace: $STRESSTEST_NAMESPACE"
log_info "Searching for status: Ready=$STRESSTEST_TARGET_STATUS"
echo "----------------------------------------"

# Get resources with the specified status
RESOURCE_NAMES=$(get_resources_by_status "$STRESSTEST_API_GROUP" "$STRESSTEST_NAMESPACE" "$STRESSTEST_TARGET_STATUS")

if [ -z "$RESOURCE_NAMES" ]; then
    log_success "No resources found with Ready=$STRESSTEST_TARGET_STATUS"
    exit 0
fi

# Count total resources
TOTAL_COUNT=$(echo "$RESOURCE_NAMES" | wc -l)

# Print summary
echo ""
log_warn "📊 SUMMARY REPORT"
echo "----------------------------------------"

if [ "$STRESSTEST_TARGET_STATUS" = "False" ]; then
    echo "Resources NOT Ready:"
else
    echo "Resources Ready:"
fi

echo "$RESOURCE_NAMES" | while IFS='/' read -r KIND NAME; do
    echo "  - $KIND: $NAME"
done

echo "----------------------------------------"

if [ "$TOTAL_COUNT" -gt 0 ]; then
    log_warn "🔴 TOTAL: $TOTAL_COUNT resources with Ready=$STRESSTEST_TARGET_STATUS"
else
    log_success "✅ All resources are healthy!"
fi