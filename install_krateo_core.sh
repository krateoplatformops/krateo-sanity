#!/bin/bash

# ==============================================================================
# install_krateo_core.sh - Install Krateo core via krateoctl
# ==============================================================================
# Purpose: Core Krateo platform installation (namespaces + krateoctl deployment)
# Cluster-agnostic: Works with KIND, EKS, GKE, Azure AKS, etc.
#
# REQUIRES: krateoctl must be installed on PATH
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh" || { echo "Error: common.sh not found"; exit 1; }
source "$SCRIPT_DIR/common.conf" || { echo "Error: common.conf not found"; exit 1; }

init_common
check_kubectl_context

log_info "Installing Krateo core platform..."
echo ""

# Step 1: Create required namespaces
log_info "Step 1: Creating namespaces..."
create_namespace_safe "$KRATEO_SYSTEM_NAMESPACE"
echo ""

# Step 2: Verify krateoctl is available
if ! command -v krateoctl &> /dev/null; then
    die "❌ krateoctl not found on PATH. Install krateoctl before proceeding:
         https://docs.krateo.io/getting-started/install-krateoctl"
fi
log_success "krateoctl is available"
echo ""

# Step 3: Install Krateo core via krateoctl
log_info "Step 2: Installing Krateo core via krateoctl..."
log_info "Version: $KRATEO_VERSION | Profile: $KRATEO_PROFILE"
echo ""

if ! ./krateoctl install apply \
    --version "$KRATEO_VERSION" \
    --profile "$KRATEO_PROFILE" \
    --init-secrets; then
    die "Failed to install Krateo core"
fi
log_success "Krateo core installed successfully"
echo ""

# Step 4: Verify installation
log_info "Step 3: Verifying Krateo installation..."
sleep 2

KRATEO_INSTALLATION=$(kubectl get installation -n "$KRATEO_SYSTEM_NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$KRATEO_INSTALLATION" ]; then
    log_warn "⚠️  Installation object not found yet - initialization may still be completing"
else
    log_success "Installation found: $KRATEO_INSTALLATION"
fi
echo ""

# Step 5: Retrieve admin credentials
log_info "Step 4: Retrieving admin credentials..."
ADMIN_PASSWORD=$(kubectl get secret admin-password -n "$KRATEO_SYSTEM_NAMESPACE" -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
if [ -z "$ADMIN_PASSWORD" ]; then
    log_warn "⚠️  admin-password secret not found yet - may still be initializing"
else
    echo ""
    log_success "✅ Krateo core installation completed!"
    echo ""
    log_info "📝 Admin Credentials:"
    log_info "  Username: admin"
    log_info "  Password: $ADMIN_PASSWORD"
    echo ""
fi

log_info "⏭️  Next steps:"
log_info "  1. Install providers: ./install_krateo_providers.sh"
log_info "  2. Setup blueprints: ./setup_blueprints.sh"
echo ""
