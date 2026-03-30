#!/bin/bash

# ==============================================================================
# check_krateo_status.sh - Check Krateo installation status
# ==============================================================================
# Purpose: Verify all Krateo components are installed and ready
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh" || { echo "Error: common.sh not found"; exit 1; }
source "$SCRIPT_DIR/../config/common.conf" || { echo "Error: common.conf not found"; exit 1; }

init_common

log_info "🔍 Krateo Installation Status Check"
log_info "===================================="
echo ""

# Check namespaces
log_info "📦 Namespaces:"
for ns in "$KRATEO_SYSTEM_NAMESPACE" "$DEMO_SYSTEM_NAMESPACE"; do
    if kubectl get namespace "$ns" &> /dev/null; then
        log_success "  ✓ $ns (exists)"
    else
        log_warn "  ✗ $ns (missing)"
    fi
done
echo ""

# Check Krateo core installation
log_info "🎯 Krateo Core:"
if INSTALLATION=$(kubectl get installation -n "$KRATEO_SYSTEM_NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); then
    log_success "  ✓ Installation: $INSTALLATION"
    STATUS=$(kubectl get installation "$INSTALLATION" -n "$KRATEO_SYSTEM_NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
    log_info "    Status: $STATUS"
else
    log_warn "  ✗ No Installation resource found"
fi
echo ""

# Check Helm releases
log_info "📊 Helm Releases (krateo-system):"
releases=$(helm list -n "$KRATEO_SYSTEM_NAMESPACE" --short 2>/dev/null | tail -n +2)
if [ -z "$releases" ]; then
    log_warn "  No releases found"
else
    echo "$releases" | while read -r release; do
        STATUS=$(helm list -n "$KRATEO_SYSTEM_NAMESPACE" | grep "^$release" | awk '{print $8}')
        log_info "  • $release ($STATUS)"
    done
fi
echo ""

# Check CompositionDefinition
log_info "🎨 Composition Definitions:"
if kubectl get compositiondefinition -n "$KRATEO_SYSTEM_NAMESPACE" 2>/dev/null | grep -q "portal-blueprint-page"; then
    READY=$(kubectl get compositiondefinition portal-blueprint-page -n "$KRATEO_SYSTEM_NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [ "$READY" = "True" ]; then
        log_success "  ✓ portal-blueprint-page (Ready)"
    else
        log_warn "  ! portal-blueprint-page (Not Ready: $READY)"
    fi
else
    log_warn "  ✗ portal-blueprint-page (not found)"
fi
echo ""

# Check PortalBlueprintPage instances
log_info "📄 Portal Blueprint Pages (demo-system):"
pages=$(kubectl get portalblueprintpage -n "$DEMO_SYSTEM_NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
if [ -z "$pages" ]; then
    log_warn "  No pages found"
else
    for page in $pages; do
        READY=$(kubectl get portalblueprintpage "$page" -n "$DEMO_SYSTEM_NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
        if [ "$READY" = "True" ]; then
            log_success "  ✓ $page (Ready)"
        else
            log_warn "  ! $page (Not Ready: $READY)"
        fi
    done
fi
echo ""

# Check admin credentials
log_info "🔑 Admin Credentials:"
if ADMIN_PASSWORD=$(kubectl get secret admin-password -n "$KRATEO_SYSTEM_NAMESPACE" -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null); then
    log_success "  ✓ admin-password secret found"
    log_info "    Username: admin"
    log_info "    Password: $ADMIN_PASSWORD"
else
    log_warn "  ✗ admin-password secret not found"
fi
echo ""

# Summary
log_info "💡 Next steps:"
log_info "  • If any components are missing, re-run the installation step:"
log_info "    - Core: ./install_krateo_core.sh"
log_info "    - Providers: ./install_krateo_providers.sh"
log_info "    - Blueprints: ./setup_blueprints.sh"
log_info "  • Or run full installation: ./initialize_krateo.sh"
echo ""
