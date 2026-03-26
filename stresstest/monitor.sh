#!/bin/bash

# ==============================================================================
# Script Name: install-on-current.sh
# Description: Installs Prometheus/Grafana on the CURRENT active cluster.
#              Does NOT create a new cluster.
# Usage: ./install-on-current.sh
# ==============================================================================

set -e

NAMESPACE="monitoring"

# 1. Verify Current Context
# We capture the current context to ensure we are installing to the right place.
CURRENT_CONTEXT=$(kubectl config current-context)

echo "------------------------------------------------------------------"
echo "Targeting Current Cluster Context: $CURRENT_CONTEXT"
echo "------------------------------------------------------------------"

# Simple confirmation prompt to prevent accidental installs
read -p "Are you sure you want to install the monitoring stack here? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
fi

# 2. Add Helm Repo
echo "Adding Prometheus Community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 3. Install/Upgrade kube-prometheus-stack
echo "Installing kube-prometheus-stack in namespace '$NAMESPACE'..."

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Install the chart
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace "$NAMESPACE" \
  --set grafana.adminPassword="admin" \
  --wait

echo "------------------------------------------------------------------"
echo "Installation Complete on $CURRENT_CONTEXT!"
echo "------------------------------------------------------------------"

# 4. Access Info
GRAFANA_SERVICE_NAME=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].metadata.name}")

echo "To access Grafana, run:"
echo ""
echo "  kubectl port-forward -n $NAMESPACE svc/$GRAFANA_SERVICE_NAME 3000:80"
echo ""
echo "Credentials: admin / admin"