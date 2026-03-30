#!/bin/bash

# ==============================================================================
# install_krateo_providers.sh - Install Krateo required providers
# ==============================================================================
# Purpose: Install composition providers and infrastructure components
# Required for: Blueprint and composition support
# Providers:
#   • github-provider-kog-repo - GitHub scaffolding provider
#   • git-provider - Git operations provider
#   • argocd - GitOps continuous deployment
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh" || { echo "Error: common.sh not found"; exit 1; }
source "$SCRIPT_DIR/../config/common.conf" || { echo "Error: common.conf not found"; exit 1; }

init_common
check_kubectl_context

log_info "Installing Krateo providers..."
echo ""

# Step 1: Verify crateo-system namespace exists
if ! kubectl get namespace "$KRATEO_SYSTEM_NAMESPACE" &> /dev/null; then
    die "Namespace $KRATEO_SYSTEM_NAMESPACE not found. Run install_krateo_core.sh first"
fi
log_success "Krateo namespace verified"
echo ""

# Step 2: Add Helm repositories
log_info "Step 1: Adding Helm repositories..."
add_helm_repo "krateo" "$KRATEO_CHARTS_REPO_URL"
add_helm_repo "cloudnative-pg" "$CLOUDNATIVE_PG_REPO_URL"
add_helm_repo "argo" "$ARGO_REPO_URL"
add_helm_repo "prometheus" "$PROMETHEUS_REPO_URL"
add_helm_repo "marketplace" "$MARKETPLACE_REPO_URL"
log_success "Helm repositories added"
echo ""

# Step 3: Install or upgrade github-provider-kog-repo
log_info "Step 2: Installing github-provider-kog-repo..."
if helm list -n "$KRATEO_SYSTEM_NAMESPACE" | grep -q "^github-provider-kog-repo"; then
    log_info "Release already exists, upgrading..."
    if ! helm upgrade github-provider-kog-repo marketplace/github-provider-kog-repo \
        --namespace "$KRATEO_SYSTEM_NAMESPACE" \
        --wait \
        --timeout 5m \
        --version 1.0.0; then
        die "Failed to upgrade github-provider-kog-repo"
    fi
else
    if ! helm install github-provider-kog-repo marketplace/github-provider-kog-repo \
        --namespace "$KRATEO_SYSTEM_NAMESPACE" \
        --create-namespace \
        --wait \
        --timeout 5m \
        --version 1.0.0; then
        die "Failed to install github-provider-kog-repo"
    fi
fi
log_success "github-provider-kog-repo installed"
echo ""

# Step 4: Install or upgrade git-provider
log_info "Step 3: Installing git-provider..."
if helm list -n "$KRATEO_SYSTEM_NAMESPACE" | grep -q "^git-provider"; then
    log_info "Release already exists, upgrading..."
    if ! helm upgrade git-provider krateo/git-provider \
        --namespace "$KRATEO_SYSTEM_NAMESPACE" \
        --wait \
        --timeout 5m \
        --version 0.10.1; then
        die "Failed to upgrade git-provider"
    fi
else
    if ! helm install git-provider krateo/git-provider \
        --namespace "$KRATEO_SYSTEM_NAMESPACE" \
        --create-namespace \
        --wait \
        --timeout 5m \
        --version 0.10.1; then
        die "Failed to install git-provider"
    fi
fi
log_success "git-provider installed"
echo ""

# Step 5: Install or upgrade ArgoCD
log_info "Step 4: Installing ArgoCD..."
if helm list -n "$KRATEO_SYSTEM_NAMESPACE" | grep -q "^argocd"; then
    log_info "Release already exists, upgrading..."
    if ! helm upgrade argocd argo/argo-cd \
        --namespace "$KRATEO_SYSTEM_NAMESPACE" \
        --wait \
        --timeout 5m \
        --version 8.0.17; then
        die "Failed to upgrade argocd"
    fi
else
    if ! helm install argocd argo/argo-cd \
        --namespace "$KRATEO_SYSTEM_NAMESPACE" \
        --create-namespace \
        --wait \
        --timeout 5m \
        --version 8.0.17; then
        die "Failed to install argocd"
    fi
fi
log_success "ArgoCD installed"
echo ""

log_success "✅ All providers installed successfully!"
echo ""
log_info "⏭️  Next step:"
log_info "  • Setup blueprints: ./setup_blueprints.sh"
echo ""
