kind create cluster --wait 120s --image kindest/node:v1.33.4 --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: krateo-quickstart
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
  - containerPort: 30080 # Krateo Portal
    hostPort: 30080
  - containerPort: 30081 # Krateo Snowplow
    hostPort: 30081
  - containerPort: 30082 # Krateo AuthN Service
    hostPort: 30082
  - containerPort: 30083 # Krateo EventSSE
    hostPort: 30083
  - containerPort: 30085 # Krateo Sweeper
    hostPort: 30085
  - containerPort: 30086 # Krateo FireworksApp Frontend
    hostPort: 30086
  - containerPort: 30088 # Krateo Smithery
    hostPort: 30088
networking:
  # By default the API server listens on a random open port.
  # You may choose a specific port but probably don't need to in most cases.
  # Using a random port makes it easier to spin up multiple clusters.
  apiServerPort: 6443
EOF


# 2. Create required namespaces
kubectl create ns krateo-system

# 3. Install Krateo
# NOTE: Ensure krateoctl is in your PATH
krateoctl install apply --version 3.0.0-rc3 --profile debug --init-secrets

helm repo add marketplace https://marketplace.krateo.io
helm repo update marketplace
helm install github-provider-kog-repo marketplace/github-provider-kog-repo --namespace krateo-system --create-namespace --wait --version 1.0.0
helm install git-provider krateo/git-provider --namespace krateo-system --create-namespace --wait --version 0.10.1
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo
helm install argocd argo/argo-cd --namespace krateo-system --create-namespace --wait --version 8.0.17

# 4. Apply the Composition Definition
cat <<EOF | kubectl apply -f -
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

# 5. Wait for the definition to be ready
# English comment: Wait for the Krateo controller to process the definition
kubectl wait --for=condition=Ready compositiondefinition/portal-blueprint-page -n krateo-system --timeout=300s

# 6. CRITICAL: Wait for the API server to recognize the new CRD
# Even if the resource is 'Ready', the API discovery cache needs a moment
sleep 5

# 7. Apply the PortalBlueprintPage instance
cat <<EOF | kubectl apply -f -
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