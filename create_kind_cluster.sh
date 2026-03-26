#!/bin/bash

# ==============================================================================
# create_kind_cluster.sh - Create a KIND cluster with Krateo-specific config
# Port mappings align with krateo.nodeport.yaml component structure
# Reference: /releases/krateo.nodeport.yaml
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh" || { echo "Error: common.sh not found"; exit 1; }

init_common
check_command "kind"

CLUSTER_NAME="${1:-krateo-quickstart}"
CLUSTER_IMAGE="${2:-kindest/node:v1.33.4}"
WAIT_TIME="120s"
API_SERVER_PORT="6443"

log_info "Creating KIND cluster: $CLUSTER_NAME"
log_info "Image: $CLUSTER_IMAGE"
log_info "Waiting up to $WAIT_TIME for cluster to be ready"

# Create KIND cluster with Krateo-specific port mappings
kind create cluster \
    --wait "$WAIT_TIME" \
    --image "$CLUSTER_IMAGE" \
    --name "$CLUSTER_NAME" \
    --config - <<'KINDCONFIG'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
  extraPortMappings:
  # Krateo platform services (see krateo.nodeport.yaml)
  - containerPort: 30080
    hostPort: 30080
    protocol: TCP
    # Frontend Portal UI
  - containerPort: 30081
    hostPort: 30081
    protocol: TCP
    # Snowplow 
  - containerPort: 30082
    hostPort: 30082
    protocol: TCP
    # AuthN (authentication service)
  - containerPort: 30083
    hostPort: 30083
    protocol: TCP
    # Events Presenter (event API)
  - containerPort: 30086
    hostPort: 30086
    protocol: TCP
    # FinOps Database Handler
networking:
  apiServerPort: 6443
KINDCONFIG

if [ $? -eq 0 ]; then
    log_success "KIND cluster '$CLUSTER_NAME' created successfully"
    log_info "Next step: Run './initialize_krateo.sh' to install Krateo components"
else
    die "Failed to create KIND cluster"
fi
