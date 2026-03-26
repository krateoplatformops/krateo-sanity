#!/bin/bash

# ==============================================================================
# initialize_krateo.sh - Initialize Krateo on any Kubernetes cluster
# Cluster-agnostic: Works with KIND, EKS, GKE, Azure AKS, etc.
#
# REQUIRES: krateoctl must be installed on PATH for full platform installation
# Reference: /releases/krateo.nodeport.yaml
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh" || { echo "Error: common.sh not found"; exit 1; }
source "$SCRIPT_DIR/common.conf" || { echo "Error: common.conf not found"; exit 1; }

init_common
check_kubectl_context

log_info "Initializing Krateo platform on Kubernetes cluster..."
echo ""

# Step 1: Create required namespaces
log_info "Step 1: Creating namespaces..."
create_namespace_safe "$KRATEO_SYSTEM_NAMESPACE"
echo ""

# Step 2: Verify krateoctl is available (required for full stack)
if ! command -v krateoctl &> /dev/null; then
    log_warn "⚠️  krateoctl not found - full Krateo platform installation will be skipped"
    log_warn "Install krateoctl to deploy the complete stack:"
    log_warn ""
    log_warn "  Krateo Platform Services (via krateoctl):"
    log_warn "    • Backend: authn (30082), snowplow (30081), events (30083)"
    log_warn "    • Database: CloudNativePG + PostgreSQL"
    log_warn "    • Frontend: Portal UI (30080)"
    log_warn "    • Composition: core-provider, oasgen-provider"
    log_warn "    • Optional: FinOps stack, OPA policy engine"
    log_warn ""
    log_warn "See: /releases/krateo.nodeport.yaml for complete stack definition"
    log_warn ""
fi

# Step 3: Add Helm repositories (for manual/fallback installation)
log_info "Step 2: Adding Helm repositories..."
add_helm_repo "krateo" "$KRATEO_CHARTS_REPO_URL"
add_helm_repo "cloudnative-pg" "$CLOUDNATIVE_PG_REPO_URL"
add_helm_repo "argo" "$ARGO_REPO_URL"
add_helm_repo "prometheus" "$PROMETHEUS_REPO_URL"
add_helm_repo "marketplace" "$MARKETPLACE_REPO_URL"
echo ""

# Step 4: Install Krateo core via krateoctl (if available)
if command -v krateoctl &> /dev/null; then
    log_info "Step 3: Installing Krateo core via krateoctl..."
    log_info "Version: $KRATEO_VERSION | Profile: $KRATEO_PROFILE"
    krateoctl install apply \
        --version "$KRATEO_VERSION" \
        --profile "$KRATEO_PROFILE" \
        --init-secrets || die "Failed to install Krateo core"
    log_success "Krateo core installed"
    log_info ""
    log_info "Platform services now available at:"
    log_info "  • Portal:  http://localhost:$KRATEO_PORTAL_PORT"
    log_info "  • AuthN:   http://localhost:$KRATEO_AUTHN_PORT"
    log_info "  • Events:  http://localhost:$KRATEO_EVENTS_PORT"
    log_info "  • Snowplow: http://localhost:$KRATEO_SNOWPLOW_PORT"
    log_info "  • FinOps Database Handler: http://localhost:$KRATEO_FINOPS_PORT"
    echo ""
else
    log_info "Step 3: Skipping krateoctl-based installation"
    log_info "To install the full platform stack, install krateoctl and run:"
    log_info "  krateoctl install apply --version $KRATEO_VERSION --profile $KRATEO_PROFILE --init-secrets"
    echo ""
fi

# Step 4b: Install required Helm charts for GitHub scaffolding composition
log_info "Step 3b: Installing required Helm charts..."
log_info "Installing github-provider-kog-repo..."
if ! helm install github-provider-kog-repo marketplace/github-provider-kog-repo \
    --namespace "$KRATEO_SYSTEM_NAMESPACE" \
    --create-namespace \
    --wait \
    --timeout 5m \
    --version 1.0.0; then
    die "Failed to install github-provider-kog-repo"
fi
log_success "github-provider-kog-repo installed"

log_info "Installing git-provider..."
if ! helm install git-provider krateo/git-provider \
    --namespace "$KRATEO_SYSTEM_NAMESPACE" \
    --create-namespace \
    --wait \
    --timeout 5m \
    --version 0.10.1; then
    die "Failed to install git-provider"
fi
log_success "git-provider installed"

log_info "Installing argocd..."
if ! helm install argocd argo/argo-cd \
    --namespace "$KRATEO_SYSTEM_NAMESPACE" \
    --create-namespace \
    --wait \
    --timeout 5m \
    --version 8.0.17; then
    die "Failed to install argocd"
fi
log_success "argocd installed"
echo ""

# Step 5: Apply Composition Definition
log_info "Step 4: Applying Composition Definition..."
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

if ! apply_kubernetes_resource "$COMPOSITION_DEF" "CompositionDefinition" "portal-blueprint-page" "krateo-system"; then
    die "Failed to apply Composition Definition"
fi

# Wait for Composition Definition to be ready
if ! wait_for_resource_condition "compositiondefinition" "portal-blueprint-page" "Ready" "krateo-system" "$DEFAULT_TIMEOUT"; then
    log_error "Timeout waiting for Composition Definition to be ready"
    die "CompositionDefinition failed to reach Ready state within ${DEFAULT_TIMEOUT}s"
fi
echo ""

# Step 6: Cache sync delay
log_info "Step 5: Waiting for API discovery sync..."
sleep_with_message 5 "Allowing API server to recognize new CRDs"
echo ""

# Step 7: Apply Portal Blueprint Page instance
log_info "Step 6: Applying Portal Blueprint Page instance..."
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

if ! apply_kubernetes_resource "$PORTAL_INSTANCE" "PortalBlueprintPage" "github-scaffolding-with-composition-page" "demo-system"; then
    die "Failed to apply Portal Blueprint Page instance"
fi
echo ""

log_success "✅ Krateo platform initialization completed!"
