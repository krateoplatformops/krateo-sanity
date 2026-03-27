#!/bin/bash

# ==============================================================================
# kind-portal-gh-scaffolding.sh - Complete Krateo quickstart with KIND
# Orchestrates cluster creation and Krateo initialization
# Reference: /releases/krateo.nodeport.yaml
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional parameters
CLUSTER_NAME="${1:-krateo-quickstart}"
CLUSTER_IMAGE="${2:-kindest/node:v1.33.4}"

echo "=============================================================================="
echo "Krateo Quickstart - KIND Cluster Setup"
echo "=============================================================================="
echo ""

# Step 1: Create KIND cluster
echo "Step 1: Creating KIND cluster..."
"$SCRIPT_DIR/create_kind_cluster.sh" "$CLUSTER_NAME" "$CLUSTER_IMAGE" || exit 1
echo ""

# Step 2: Initialize Krateo
echo "Step 2: Initializing Krateo platform..."
"$SCRIPT_DIR/initialize_krateo.sh" || exit 1
echo ""

echo "=============================================================================="
echo "✅ Krateo cluster is ready!"
echo "=============================================================================="
echo ""
echo "Cluster: $CLUSTER_NAME"
echo "API Server: $(kubectl cluster-info | grep 'Kubernetes master' | awk '{print $NF}')"
echo ""
echo "Service Access (NodePort):"
echo "  📊 Portal:             http://localhost:30080"
echo "  🔐 AuthN Service:      http://localhost:30082"
echo "  📡 Snowplow Events:    http://localhost:30081"
echo "  📈 Events API:         http://localhost:30083"
echo ""
echo "📘 Full Platform Stack: See /releases/krateo.nodeport.yaml"
echo "    Install krateoctl to deploy complete backend services."
echo ""
echo "✓ Cluster is ready for stress testing"
echo "  Run: cd stresstest && ./stresstest_setup.sh"
echo ""
echo "Next steps:"
echo "  1. Access Krateo Portal: http://localhost:30080"
echo "  2. Run stress tests: ./stresstest/stresstest_setup.sh && ./stresstest/stresstest_create_resources.sh"
echo "  3. Monitor resources: ./stresstest/stresstest_composition_status.sh"
echo ""