#!/bin/bash

# --- Configuration ---

# The script now accepts two arguments: START_INDEX and END_INDEX.
# If no arguments are provided, it defaults to a range of 1 to 5.

# Default values
START_INDEX=1
END_INDEX=5

# --- Argument Parsing ---

# Check if two arguments were provided
if [ "$#" -eq 2 ]; then
    START_INDEX=$1
    END_INDEX=$2
elif [ "$#" -ne 0 ]; then
    # Handle incorrect number of arguments (not 0 or 2)
    echo "Usage: $0 [START_INDEX] [END_INDEX]"
    echo "Example 1 (Default): $0"
    echo "Example 2 (Range 10 to 15): $0 10 15"
    exit 1
fi

# Calculate the total count for logging purposes
COUNT=$((END_INDEX - START_INDEX + 1))
if [ $COUNT -le 0 ]; then
    echo "ERROR: END_INDEX ($END_INDEX) must be greater than or equal to START_INDEX ($START_INDEX)."
    exit 1
fi

# The base YAML manifest content with the RESOURCE_NAME placeholder.
# This template is for a Krateo Composition (GithubScaffolding).
YAML_TEMPLATE="
apiVersion: composition.krateo.io/v1-2-2
kind: GithubScaffoldingWithCompositionPage
metadata:
  name: RESOURCE_NAME
  namespace: stresstest-system
  annotations:
    krateo.io/connector-verbose: \"false\"
spec:
  argocd:
    namespace: krateo-system
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
      port: 31180
  git:
    unsupportedCapabilities: true
    insecure: true
    fromRepo:
      scmUrl: https://github.com
      org: krateoplatformops-blueprints
      name: github-scaffolding-lifecycle
      branch: main
      path: skeleton/
      credentials:
        authMethod: generic
        secretRef:
          namespace: krateo-system
          name: github-repo-creds
          key: token
    toRepo:
      scmUrl: https://github.com
      org: krateoplatformops-test
      name: postdemoday-1
      branch: main
      path: /
      credentials:
        authMethod: generic
        secretRef:
          namespace: krateo-system
          name: github-repo-creds
          key: token
      private: false
      initialize: true
      deletionPolicy: Delete
      verbose: false
      configurationRef:
        name: repo-config
        namespace: demo-system
"

# --- Main Logic ---

echo "Starting the generation and application of $COUNT resources (from index $START_INDEX to $END_INDEX)..."

# Loop from START_INDEX up to END_INDEX.
for i in $(seq $START_INDEX $END_INDEX); do
    # Define a unique resource name using the loop index (i).
    RESOURCE_NAME="stresstest-resource-$i"
    
    echo "Processing resource: $RESOURCE_NAME (Index $i)"

    # 1. Use 'echo' to output the YAML template.
    # 2. Use 'sed' to perform a string replacement:
    #    - Replace the literal string 'RESOURCE_NAME' with the dynamic value from the shell variable $RESOURCE_NAME.
    # 3. Pipe the final YAML content directly to 'kubectl apply -f -'.
    #    The '-' tells kubectl to read the YAML content from standard input (stdin).
    echo "$YAML_TEMPLATE" | sed "s/RESOURCE_NAME/$RESOURCE_NAME/g" | kubectl apply --wait=false --grace-period=0 -f -

    # Check the exit status of the previous command (kubectl apply).
    if [ $? -eq 0 ]; then
        echo "Successfully applied $RESOURCE_NAME"
    else
        # Print an error message if kubectl failed.
        echo "ERROR: Failed to apply $RESOURCE_NAME"
        # Optionally, you can uncomment the next line to stop the script on the first error.
        # exit 1
    fi

    # Optional: Add a small delay between applications if needed, for rate limiting/stability.
    # sleep 0.5
done

echo "Finished applying resources in the range $START_INDEX to $END_INDEX."