#!/bin/bash

# ==============================================================================
# common.sh - Shared utilities for all scripts
# ==============================================================================

set -o pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*"
}

# Exit with error message
die() {
    log_error "$*"
    exit 1
}

# ============================================================================
# Directory Functions
# ============================================================================

get_script_dir() {
    cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd
}

get_project_dir() {
    cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd
}

# ============================================================================
# Kubernetes Functions
# ============================================================================

create_namespace_safe() {
    local namespace="$1"
    if kubectl get namespace "$namespace" &> /dev/null; then
        log_info "Namespace '$namespace' already exists"
    else
        log_info "Creating namespace '$namespace'..."
        kubectl create namespace "$namespace" || die "Failed to create namespace '$namespace'"
        log_success "Namespace '$namespace' created"
    fi
}

wait_for_crd() {
    local crd_name="$1"
    local timeout="${2:-300}" # Default 5 minutes
    local elapsed=0
    local interval=5

    log_info "Waiting for CRD '$crd_name' to be ready (timeout: ${timeout}s)..."
    
    while [ $elapsed -lt $timeout ]; do
        if kubectl get crd "$crd_name" &> /dev/null; then
            log_success "CRD '$crd_name' is ready"
            return 0
        fi
        log_info "  Waiting... ($elapsed/${timeout}s)"
        sleep $interval
        ((elapsed += interval))
    done
    
    die "Timeout waiting for CRD '$crd_name'"
}

wait_for_deployment() {
    local namespace="$1"
    local deployment="$2"
    local timeout="${3:-300}" # Default 5 minutes

    log_info "Waiting for deployment '$deployment' in namespace '$namespace' to be ready..."
    kubectl rollout status deployment/"$deployment" -n "$namespace" --timeout="${timeout}s" || \
        die "Timeout waiting for deployment '$deployment'"
    log_success "Deployment '$deployment' is ready"
}

# ============================================================================
# Helm Functions
# ============================================================================

add_helm_repo() {
    local repo_name="$1"
    local repo_url="$2"
    
    log_info "Adding Helm repository: $repo_name"
    if helm repo add "$repo_name" "$repo_url" 2>/dev/null; then
        log_success "Helm repository '$repo_name' added"
    else
        # Check if repo already exists
        if helm repo list | grep -q "^$repo_name"; then
            log_info "Helm repository '$repo_name' already exists, updating..."
        else
            die "Failed to add Helm repo '$repo_name'"
        fi
    fi
    helm repo update "$repo_name" || die "Failed to update Helm repo '$repo_name'"
}

helm_install_or_upgrade() {
    local release_name="$1"
    local chart="$2"
    local namespace="$3"
    shift 3
    local extra_args=("$@")

    log_info "Installing/upgrading Helm release: $release_name"
    helm upgrade --install "$release_name" "$chart" \
        --namespace "$namespace" \
        --create-namespace \
        "${extra_args[@]}" || die "Failed to install Helm chart '$chart'"
    log_success "Helm release '$release_name' deployed"
}

# Install multiple Helm charts from array configuration
# Usage: helm_install_charts_from_config namespace "chart1:version1" "chart2:version2"
helm_install_charts_from_config() {
    local namespace="$1"
    shift
    local charts=("$@")
    
    log_info "Installing ${#charts[@]} Helm charts in namespace '$namespace'..."
    
    local failed_count=0
    for chart_spec in "${charts[@]}"; do
        local release_name=$(echo "$chart_spec" | cut -d: -f1)
        local chart=$(echo "$chart_spec" | cut -d: -f2)
        local version=$(echo "$chart_spec" | cut -d: -f3)
        
        log_info "  Installing: $release_name from $chart (version $version)..."
        if helm upgrade --install "$release_name" "$chart" \
            --namespace "$namespace" \
            --create-namespace \
            --version "$version" \
            --wait > /dev/null 2>&1; then
            log_success "  ✓ $release_name installed"
        else
            log_error "  ✗ Failed to install $release_name"
            ((failed_count++))
        fi
    done
    
    if [ $failed_count -gt 0 ]; then
        log_error "Failed to install $failed_count chart(s)"
        return 1
    fi
    log_success "All charts installed successfully"
    return 0
}

# ============================================================================
# Validation Functions
# ============================================================================

check_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        die "Required command not found: $cmd"
    fi
}

check_kubectl_context() {
    local context=$(kubectl config current-context)
    log_info "Current Kubernetes context: $context"
}

validate_range() {
    local start="$1"
    local end="$2"
    
    if ! [[ "$start" =~ ^[0-9]+$ ]] || ! [[ "$end" =~ ^[0-9]+$ ]]; then
        die "Range values must be integers. Got: $start to $end"
    fi
    
    if [ "$end" -lt "$start" ]; then
        die "END_INDEX ($end) must be >= START_INDEX ($start)"
    fi
}

# ============================================================================
# Resource Functions
# ============================================================================

apply_yaml() {
    local yaml_content="$1"
    local resource_name="${2:-resource}"
    local error_output
    
    error_output=$(echo "$yaml_content" | kubectl apply --wait=false --grace-period=0 -f - 2>&1)
    if [ $? -eq 0 ]; then
        log_success "Applied $resource_name"
        return 0
    else
        log_error "Failed to apply $resource_name"
        echo "$error_output" | sed 's/^/  /'  # Indent error output for readability
        return 1
    fi
}

# Apply Kubernetes resource from YAML string with condition waiting
apply_kubernetes_resource() {
    local yaml_content="$1"
    local resource_type="${2:-resource}"
    local resource_name="${3:-}"
    local namespace="${4:-}"
    
    local desc="${resource_type}"
    [ -n "$resource_name" ] && desc="$resource_type/$resource_name"
    
    log_info "Applying $desc..."
    if echo "$yaml_content" | kubectl apply -f - > /dev/null 2>&1; then
        log_success "Applied $desc"
        return 0
    else
        log_error "Failed to apply $desc"
        return 1
    fi
}

# Wait for a Kubernetes resource to have a specific condition
wait_for_resource_condition() {
    local resource_type="$1"
    local resource_name="$2"
    local condition="$3"
    local namespace="${4:-default}"
    local timeout="${5:-300}"
    
    log_info "Waiting for $resource_type/$resource_name condition=$condition (timeout=${timeout}s)..."
    
    if kubectl wait --for=condition="$condition" "$resource_type/$resource_name" \
        -n "$namespace" --timeout="${timeout}s" > /dev/null 2>&1; then
        log_success "$resource_type/$resource_name is $condition"
        return 0
    else
        log_error "Timeout waiting for $resource_type/$resource_name condition=$condition"
        return 1
    fi
}

# Sleep with explicit feedback
sleep_with_message() {
    local seconds="$1"
    local message="${2:-Waiting}"
    
    log_info "$message ($seconds seconds)..."
    sleep "$seconds"
}

get_resources_by_status() {
    local api_group="$1"
    local namespace="$2"
    local ready_status="$3"
    
    local plural_names=$(kubectl api-resources --api-group="$api_group" --namespaced=true -o wide 2>/dev/null | awk 'NR>1 {print $1}')
    
    if [ -z "$plural_names" ]; then
        log_error "No resources found for API Group: $api_group"
        return 1
    fi
    
    local results=()
    for plural_name in $plural_names; do
        local names=$(kubectl get "$plural_name.$api_group" -n "$namespace" -o json 2>/dev/null | \
            jq -r ".items[] | select(.status.conditions[]? | select(.type==\"Ready\" and .status==\"$ready_status\")) | .metadata.name")
        
        if [ -n "$names" ]; then
            for name in $names; do
                results+=("$plural_name/$name")
            done
        fi
    done
    
    printf '%s\n' "${results[@]}"
}

# ============================================================================
# Version Resolution Functions
# ============================================================================

# Fetch latest release from GitHub API (including pre-releases)
# Tries releases endpoint first, falls back to tags endpoint
# Usage: get_latest_github_release "krateoplatformops" "releases" ["include-rc"]
get_latest_github_release() {
    local owner="$1"
    local repo="$2"
    local include_rc="${3:-true}"
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is required for version resolution"
        return 1
    fi
    
    local response
    local latest_tag
    
    # Try releases endpoint first
    local api_url="https://api.github.com/repos/$owner/$repo/releases"
    response=$(curl -s --max-time 10 "$api_url" 2>/dev/null)
    
    if [ -z "$response" ]; then
        log_error "Failed to fetch releases from GitHub API for $owner/$repo"
        return 1
    fi
    
    # Check if we got releases
    if [ "$include_rc" = "true" ]; then
        latest_tag=$(echo "$response" | jq -r '.[0].tag_name' 2>/dev/null)
    else
        # Exclude pre-releases from releases endpoint
        latest_tag=$(echo "$response" | jq -r '.[] | select(.prerelease == false) | .tag_name' 2>/dev/null | head -1)
    fi
    
    # If no releases, try tags endpoint as fallback
    if [ -z "$latest_tag" ] || [ "$latest_tag" = "null" ]; then
        api_url="https://api.github.com/repos/$owner/$repo/tags"
        response=$(curl -s --max-time 10 "$api_url" 2>/dev/null)
        
        if [ -n "$response" ] && [ "$response" != "[]" ]; then
            if [ "$include_rc" = "true" ]; then
                # Get latest tag (first in list)
                latest_tag=$(echo "$response" | jq -r '.[0].name' 2>/dev/null)
            else
                # Filter out RC/alpha/beta/dev versions - keep only stable versions
                latest_tag=$(echo "$response" | jq -r '.[] | select(.name | test("-rc|-alpha|-beta|-dev"; "i") | not) | .name' 2>/dev/null | head -1)
                
                # If no stable versions found, still return empty (don't fall back to RC)
                if [ -z "$latest_tag" ] || [ "$latest_tag" = "null" ]; then
                    return 1
                fi
            fi
        fi
    fi
    
    if [ -z "$latest_tag" ] || [ "$latest_tag" = "null" ]; then
        return 1
    fi
    
    # Clean up tag name (remove leading 'v' if present)
    echo "$latest_tag" | sed 's/^v//'
}

# Fetch latest release with fallback to default version
# Usage: get_version "krateoplatformops" "krateoctl" "0.1.0" "true"
# NOTE: Only outputs the version to stdout (logging goes to stderr)
get_version() {
    local owner="$1"
    local repo="$2"
    local default_version="$3"
    local include_rc="${4:-true}"
    
    if [ $# -lt 2 ]; then
        log_error "get_version requires at least: owner repo [default_version] [include_rc]" >&2
        return 1
    fi
    
    local latest_version
    latest_version=$(get_latest_github_release "$owner" "$repo" "$include_rc")
    
    # If fetch failed or returned empty, use default version
    if [ -z "$latest_version" ]; then
        log_warn "Failed to fetch latest release for $owner/$repo, using default: $default_version" >&2
        echo "$default_version"
        return 0
    fi
    
    log_info "Latest version for $owner/$repo: $latest_version" >&2
    echo "$latest_version"
}

# Get latest Helm chart version from Helm repository
# Usage: get_latest_helm_chart_version "krateo/git-provider"
# NOTE: Only outputs the version to stdout (logging goes to stderr)
get_latest_helm_chart_version() {
    local chart_name="$1"
    local repo_name="${chart_name%%/*}"
    local chart="${chart_name##*/}"
    
    if ! command -v helm &> /dev/null; then
        log_error "helm is required for chart version resolution" >&2
        return 1
    fi
    
    # Ensure repo is updated (output to stderr)
    helm repo update "$repo_name" > /dev/null 2>&1 || {
        log_warn "Failed to update Helm repo: $repo_name" >&2
        return 1
    }
    
    # Search for latest version and only output version to stdout
    helm search repo "$chart_name" --output json 2>/dev/null | \
        jq -r '.[0].version' 2>/dev/null || {
        log_error "Failed to find chart: $chart_name" >&2
        return 1
    }
}

# ============================================================================
# Confirmation Functions
# ============================================================================

confirm_action() {
    local prompt="$1"
    local response
    
    read -p "$prompt (y/n) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# ============================================================================
# Initialization
# ============================================================================

init_common() {
    # Verify required commands exist
    check_command "kubectl"
    check_command "helm"
    check_command "jq"
    
    # Set up error handling
    trap 'log_error "Script interrupted"; exit 130' INT
}
