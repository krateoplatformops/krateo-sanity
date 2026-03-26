#!/bin/bash

# Source common utilities and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh" || { echo "Error: common.sh not found"; exit 1; }
source "$SCRIPT_DIR/stresstest.conf" || { echo "Error: stresstest.conf not found"; exit 1; }

# Define namespace and log file
NAMESPACE="test-system"
LOG_FILE="stresstest/memory_snapshots_$(date +%Y%m%d_%H%M%S).log"
# Sampling interval in seconds (e.g., 60 seconds)
INTERVAL=60 
# Duration of the stresstest in minutes (e.g., 120 minutes = 2 hours)
DURATION_MINUTES=120 

# Calculate the number of iterations
ITERATIONS=$((DURATION_MINUTES * 60 / INTERVAL))

echo "Starting memory usage monitoring for ${DURATION_MINUTES} minutes (Snapshot every ${INTERVAL}s)..."
echo "Results will be saved to: ${LOG_FILE}"

# Write header to the log file
echo "TIMESTAMP,POD_NAME,MEMORY_USAGE_Mi" > "${LOG_FILE}"

for ((i=1; i<=ITERATIONS; i++)); do
  TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Get memory usage for all pods in the namespace, using --no-headers and formatting
  # The output is parsed to get only NAME and MEMORY(bytes/Mi/Gi)
  kubectl top pod --namespace "${NAMESPACE}" --no-headers 2>/dev/null | 
  awk '{
      # Get the usage value and the unit (bytes, Mi, Gi)
      usage = $2
      unit = substr(usage, length(usage)-1)
      val = substr(usage, 1, length(usage)-2)
      
      # Standardize the memory unit to MiB (assuming no unit means bytes)
      if (unit == "Gi") {
          mib_val = val * 1024
      } else if (unit == "Mi") {
          mib_val = val
      } else if (unit ~ /[0-9]i/) { # Handle single-digit Mi/Gi if it exists (less common)
          mib_val = substr(usage, 1, length(usage)-2)
      } else if (unit ~ /B/) { # Handle bytes (B)
          mib_val = substr(usage, 1, length(usage)-1) / 1024 / 1024
      } else {
          # Assume default unit is Mi if parsing failed (or is not present)
          mib_val = usage
      }
      
      # Print the data in CSV format
      printf "%s,%s,%.2f\n", "'"${TIMESTAMP}"'", $1, mib_val
  }' >> "${LOG_FILE}"
  
  echo "Snapshot ${i}/${ITERATIONS} taken. Sleeping for ${INTERVAL} seconds..."
  sleep "${INTERVAL}"
done

echo "Monitoring complete. Data is in ${LOG_FILE}"