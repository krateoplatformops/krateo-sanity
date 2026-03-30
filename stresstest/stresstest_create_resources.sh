#!/bin/bash

# ==============================================================================
# stresstest_create_resources.sh - Create Krateo resources for stress testing
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh" || { echo "Error: common.sh not found"; exit 1; }
source "$SCRIPT_DIR/../config/stresstest.conf" || { echo "Error: stresstest.conf not found"; exit 1; }

init_common

# Default values
START_INDEX="${DEFAULT_RESOURCE_START}"
END_INDEX="${DEFAULT_RESOURCE_END}"

# --- Argument Parsing ---

if [ "$#" -eq 2 ]; then
    START_INDEX=$1
    END_INDEX=$2
elif [ "$#" -ne 0 ]; then
    die "Usage: $0 [START_INDEX] [END_INDEX]
Example 1 (Default): $0
Example 2 (Range 10 to 15): $0 10 15"
fi

# Validate range
validate_range "$START_INDEX" "$END_INDEX"

# Calculate the total count for logging purposes
COUNT=$((END_INDEX - START_INDEX + 1))

# YAML template for Krateo resources
read -r -d '' YAML_TEMPLATE << 'EOF'
apiVersion: composition.krateo.io/v1-2-2
kind: GithubScaffoldingWithCompositionPage
metadata:
  name: RESOURCE_NAME
  namespace: NAMESPACE_PLACEHOLDER
  annotations:
    krateo.io/connector-verbose: "false"
spec:
  argocd:
    namespace: KRATEO_SYSTEM_NAMESPACE
    application:
      project: default
      source:
        path: chart/
      destination:
        server: https://kubernetes.default.svc
        namespace: fireworks-app
      syncEnabled: false
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  app:
    service:
      type: NodePort
      port: APP_SERVICE_PORT
  git:
    unsupportedCapabilities: true
    insecure: true
    fromRepo:
      scmUrl: https://github.com
      org: GITHUB_ORG_SOURCE
      name: GITHUB_REPO_SOURCE
      branch: GITHUB_BRANCH
      path: skeleton/
      credentials:
        authMethod: generic
        secretRef:
          namespace: GITHUB_SECRET_NAMESPACE
          name: GITHUB_SECRET_NAME
          key: GITHUB_SECRET_KEY
    toRepo:
      scmUrl: https://github.com
      org: GITHUB_ORG_TARGET
      name: GITHUB_REPO_TARGET
      branch: GITHUB_BRANCH
      path: /
      credentials:
        authMethod: generic
        secretRef:
          namespace: GITHUB_SECRET_NAMESPACE
          name: GITHUB_SECRET_NAME
          key: GITHUB_SECRET_KEY
      private: false
      initialize: true
      deletionPolicy: Delete
      verbose: false
      configurationRef:
        name: repo-config
        namespace: demo-system
EOF

# --- Main Logic ---

echo "Starting the generation and application of $COUNT resources (from index $START_INDEX to $END_INDEX)..."
log_info "Starting generation and application of $COUNT resources (from index $START_INDEX to $END_INDEX)"

SUCCESS_COUNT=0
FAILED_COUNT=0

# Loop from START_INDEX up to END_INDEX
for i in $(seq "$START_INDEX" "$END_INDEX"); do
    RESOURCE_NAME="${RESOURCE_PREFIX}-$i"
    
    # Substitute placeholders in YAML template
    YAML_CONTENT="$YAML_TEMPLATE"
    YAML_CONTENT="${YAML_CONTENT//RESOURCE_NAME/$RESOURCE_NAME}"
    YAML_CONTENT="${YAML_CONTENT//NAMESPACE_PLACEHOLDER/$STRESSTEST_NAMESPACE}"
    YAML_CONTENT="${YAML_CONTENT//KRATEO_SYSTEM_NAMESPACE/$KRATEO_SYSTEM_NAMESPACE}"
    YAML_CONTENT="${YAML_CONTENT//APP_SERVICE_PORT/$APP_SERVICE_PORT}"
    YAML_CONTENT="${YAML_CONTENT//GITHUB_ORG_SOURCE/$GITHUB_ORG_SOURCE}"
    YAML_CONTENT="${YAML_CONTENT//GITHUB_REPO_SOURCE/$GITHUB_REPO_SOURCE}"
    YAML_CONTENT="${YAML_CONTENT//GITHUB_BRANCH/$GITHUB_BRANCH}"
    YAML_CONTENT="${YAML_CONTENT//GITHUB_SECRET_NAMESPACE/$GITHUB_SECRET_NAMESPACE}"
    YAML_CONTENT="${YAML_CONTENT//GITHUB_SECRET_NAME/$GITHUB_SECRET_NAME}"
    YAML_CONTENT="${YAML_CONTENT//GITHUB_SECRET_KEY/$GITHUB_SECRET_KEY}"
    YAML_CONTENT="${YAML_CONTENT//GITHUB_ORG_TARGET/$GITHUB_ORG_TARGET}"
    YAML_CONTENT="${YAML_CONTENT//GITHUB_REPO_TARGET/$GITHUB_REPO_TARGET}"
    
    if apply_yaml "$YAML_CONTENT" "$RESOURCE_NAME"; then
        ((SUCCESS_COUNT++))
    else
        ((FAILED_COUNT++))
    fi
done

# Summary
echo ""
log_info "Job completed!"
log_success "Successfully applied: $SUCCESS_COUNT resources"
if [ "$FAILED_COUNT" -gt 0 ]; then
    log_warn "Failed: $FAILED_COUNT resources"
fi