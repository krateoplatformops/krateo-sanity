#!/bin/bash

# ==============================================================================
# setup_blueprints.sh - Setup Krateo composition definitions and blueprints
# ==============================================================================
# Purpose: Apply composition definitions and blueprint page instances
# Resources:
#   • CompositionDefinition: portal-blueprint-page
#   • PortalBlueprintPage: github-scaffolding-with-composition-page
# Prerequisites:
#   • Krateo core installed (install_krateo_core.sh)
#   • Providers installed (install_krateo_providers.sh)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh" || { echo "Error: common.sh not found"; exit 1; }
source "$SCRIPT_DIR/common.conf" || { echo "Error: common.conf not found"; exit 1; }

init_common
check_kubectl_context

log_info "Setting up Krateo composition definitions and blueprints..."
echo ""

# Step 1: Verify required namespaces exist
log_info "Step 1: Verifying required namespaces..."
if ! kubectl get namespace "$KRATEO_SYSTEM_NAMESPACE" &> /dev/null; then
    die "Namespace $KRATEO_SYSTEM_NAMESPACE not found. Run install_krateo_core.sh first"
fi
create_namespace_safe "$DEMO_SYSTEM_NAMESPACE"
log_success "Namespaces verified"
echo ""

# Step 2: Apply Composition Definition
log_info "Step 2: Applying CompositionDefinition (portal-blueprint-page)..."
read -r -d '' COMPOSITION_DEF << 'EOF'
apiVersion: core.krateo.io/v1alpha1
kind: CompositionDefinition
metadata:
  name: portal-blueprint-page
  namespace: krateo-system
spec:
  chart:
    repo: portal-blueprint-page
    url: https://marketplace.krateo.io
    version: 1.0.6
EOF

if ! apply_kubernetes_resource "$COMPOSITION_DEF" "CompositionDefinition" "portal-blueprint-page" "$KRATEO_SYSTEM_NAMESPACE"; then
    die "Failed to apply CompositionDefinition"
fi
log_success "CompositionDefinition applied"
echo ""

# Step 3: Wait for Composition Definition to be ready
log_info "Step 3: Waiting for CompositionDefinition to be ready..."
if ! wait_for_resource_condition "compositiondefinition" "portal-blueprint-page" "Ready" "$KRATEO_SYSTEM_NAMESPACE" "$DEFAULT_TIMEOUT"; then
    log_error "Timeout waiting for CompositionDefinition to be ready"
    die "CompositionDefinition failed to reach Ready state within ${DEFAULT_TIMEOUT}s"
fi
log_success "CompositionDefinition is ready"
echo ""

# Step 4: Cache sync delay
log_info "Step 4: Waiting for API discovery sync..."
sleep_with_message 5 "Allowing API server to recognize new CRDs"
echo ""

# Step 5: Apply Portal Blueprint Page instance
log_info "Step 5: Applying PortalBlueprintPage instance..."
read -r -d '' PORTAL_INSTANCE << 'EOF'
apiVersion: composition.krateo.io/v1-0-6
kind: PortalBlueprintPage
metadata:
  name: github-scaffolding-with-composition-page
  namespace: demo-system
spec:
  blueprint:
    repo: github-scaffolding-with-composition-page
    url: https://marketplace.krateo.io
    version: 1.2.2
    hasPage: true
  form:
    alphabeticalOrder: false
  panel:
    title: GitHub Scaffolding with Composition Page
    icon:
      name: fa-cubes
EOF

if ! apply_kubernetes_resource "$PORTAL_INSTANCE" "PortalBlueprintPage" "github-scaffolding-with-composition-page" "$DEMO_SYSTEM_NAMESPACE"; then
    die "Failed to apply PortalBlueprintPage instance"
fi
log_success "PortalBlueprintPage instance applied"
echo ""

log_success "✅ Blueprint setup completed successfully!"
echo ""
log_info "📋 Applied resources:"
log_info "  • CompositionDefinition: portal-blueprint-page (krateo-system)"
log_info "  • PortalBlueprintPage: github-scaffolding-with-composition-page (demo-system)"
echo ""
