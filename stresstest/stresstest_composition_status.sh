#!/bin/bash

# Configuration
API_GROUP="composition.krateo.io"
NAMESPACE="stresstest-system"
TARGET_STATUS="False"

echo "--- Kubernetes Resource Ready=False List ---"
echo "Target API Group: ${API_GROUP}"
echo "Target Namespace: ${NAMESPACE}"
echo "Searching for status: Ready=${TARGET_STATUS}"
echo "----------------------------------------"

RESOURCES_PLURAL=$(kubectl api-resources --api-group="${API_GROUP}" --namespaced=true -o wide 2>/dev/null | awk 'NR>1 {print $1}')

if [ -z "${RESOURCES_PLURAL}" ]; then
  echo "❌ Error: No resources found for API Group: ${API_GROUP}."
  exit 1
fi

ALL_FALSE_RESOURCES=()
# We'll use this to keep track of counts per Kind
declare -A KIND_COUNTS

for PLURAL_NAME in ${RESOURCES_PLURAL}; do
  echo "Processing resource Kind: ${PLURAL_NAME}.${API_GROUP}..."
  
  # Fetching only the names directly using jq's -r (raw) output for easier parsing
  RESOURCE_NAMES=$(kubectl get "${PLURAL_NAME}.${API_GROUP}" -n "${NAMESPACE}" -o json 2>/dev/null | \
    jq -r '.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status=="'${TARGET_STATUS}'")) | .metadata.name')

  if [ -n "${RESOURCE_NAMES}" ]; then
    COUNT=0
    for NAME in ${RESOURCE_NAMES}; do
      FULL_RESOURCE_NAME="${PLURAL_NAME}/${NAME}"
      ALL_FALSE_RESOURCES+=("${FULL_RESOURCE_NAME}")
      ((COUNT++))
    done
    KIND_COUNTS["${PLURAL_NAME}"]=$COUNT
    echo "  -> Found ${COUNT} resources."
  else
    echo "  -> No resources found with Ready=${TARGET_STATUS}."
  fi
done

# --- FINAL SUMMARY ---
echo ""
echo "--------------------------------------------------"
echo "📊 SUMMARY REPORT"
echo "--------------------------------------------------"

TOTAL_COUNT=${#ALL_FALSE_RESOURCES[@]}

if [ $TOTAL_COUNT -gt 0 ]; then
    echo "Breakdown by Kind:"
    for KIND in "${!KIND_COUNTS[@]}"; do
        echo "  - ${KIND}: ${KIND_COUNTS[$KIND]}"
    done
    echo "--------------------------------------------------"
    echo "🔴 TOTAL RESOURCES WITH Ready=${TARGET_STATUS}: ${TOTAL_COUNT}"
    echo "--------------------------------------------------"
    # Optional: List all names
    # printf '%s\n' "${ALL_FALSE_RESOURCES[@]}"
else
    echo "✅ No resources found with Ready=${TARGET_STATUS}."
fi