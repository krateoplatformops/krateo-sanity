#!/bin/bash

# ==============================================================================
# initialize_krateo.sh - Orchestrate complete Krateo installation
# ==============================================================================
# Purpose: Wrapper script that orchestrates all Krateo installation steps
# Modes:
#   Full installation:    ./initialize_krateo.sh
#   Custom orchestration: Chain individual scripts as needed
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh" || { echo "Error: common.sh not found"; exit 1; }
source "$SCRIPT_DIR/../config/common.conf" || { echo "Error: common.conf not found"; exit 1; }

init_common

log_info "🚀 Krateo Installation Orchestrator"
log_info "======================================="
echo ""

# Check if scripts exist
for script in install_krateo_core.sh install_krateo_providers.sh setup_blueprints.sh; do
    if [ ! -f "$SCRIPT_DIR/$script" ]; then
        die "Missing required script: $script"
    fi
done
log_success "All installation scripts found"
echo ""

# Execute installation steps
log_info "Starting installation workflow..."
echo ""

# Step 1: Install Krateo core
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "STEP 1/3: Install Krateo Core"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ! bash "$SCRIPT_DIR/install_krateo_core.sh"; then
    die "Failed at Step 1: Krateo core installation"
fi
echo ""

# Step 2: Install providers
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "STEP 2/3: Install Krateo Providers"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ! bash "$SCRIPT_DIR/install_krateo_providers.sh"; then
    die "Failed at Step 2: Provider installation"
fi
echo ""

# Step 3: Setup blueprints
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_info "STEP 3/3: Setup Blueprints"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ! bash "$SCRIPT_DIR/setup_blueprints.sh"; then
    die "Failed at Step 3: Blueprint setup"
fi
echo ""

# Final summary
log_success "✅ Complete Krateo Installation Successful!"
echo ""
log_info "📊 Installation Summary:"
log_info "  ✓ Krateo core platform deployed"
log_info "  ✓ Composition providers installed"
log_info "  ✓ Blueprint definitions configured"
echo ""

ADMIN_PASSWORD=$(kubectl get secret admin-password -n "$KRATEO_SYSTEM_NAMESPACE" -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
if [ -n "$ADMIN_PASSWORD" ]; then
    log_info "📝 Admin Credentials:"
    log_info "  Username: admin"
    log_info "  Password: $ADMIN_PASSWORD"
    echo ""
fi

log_info "🔗 Quick Links:"
log_info "  • Portal:  http://localhost:$KRATEO_PORTAL_PORT"
log_info "  • AuthN:   http://localhost:$KRATEO_AUTHN_PORT"
log_info "  • Events:  http://localhost:$KRATEO_EVENTS_PORT"
log_info "  • Snowplow: http://localhost:$KRATEO_SNOWPLOW_PORT"
echo ""
