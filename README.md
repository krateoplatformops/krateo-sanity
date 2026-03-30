# Krateo Sanity Check 

Framework for validating Krateo installation and stress testing.

## 🚀 Quick Start

### Complete Setup (All-in-One)
```bash
./setup/kind-portal-gh-scaffolding.sh
```

### Manual Installation (Recommended)
Separate, progressive installation with better control:

```bash
# 1. Create KIND cluster
./setup/create_kind_cluster.sh my-cluster

# 2. Install Krateo core platform (requires krateoctl)
./setup/install_krateo_core.sh

# 3. Install composition providers
./setup/install_krateo_providers.sh

# 4. Setup blueprint definitions & instances
./setup/setup_blueprints.sh
```

### Combined Setup (Orchestrated)
```bash
# Same as all-in-one, but using individual steps
./setup/initialize_krateo.sh
```

## 🔧 Installation Scripts

### Setup Directory (`setup/`)

#### `create_kind_cluster.sh` - Create Kubernetes Cluster
```bash
./setup/create_kind_cluster.sh [cluster-name] [node-image]
./setup/create_kind_cluster.sh my-cluster kindest/node:v1.33.4
```

#### `install_krateo_core.sh` - Install Krateo Core Platform
Installs Krateo core services via krateoctl (namespaces, authentication, events, portal UI).

**Prerequisites:**
- `krateoctl` must be installed on PATH

```bash
./setup/install_krateo_core.sh
```

**What it does:**
- Creates `krateo-system` namespace
- Verifies krateoctl availability  
- Runs `krateoctl install apply` with configured profile
- Retrieves admin credentials

#### `install_krateo_providers.sh` - Install Composition Providers
Installs providers required for blueprint and composition support.

**Prerequisites:**
- Krateo core must be installed (run `install_krateo_core.sh` first)

```bash
./setup/install_krateo_providers.sh
```

**Providers installed:**
- `github-provider-kog-repo` - GitHub scaffolding provider
- `git-provider` - Git operations provider  
- `argocd` - GitOps continuous deployment

#### `setup_blueprints.sh` - Setup Blueprint Definitions
Applies composition definitions and blueprint page instances.

**Prerequisites:**
- All providers must be installed (run `install_krateo_providers.sh` first)

```bash
./setup/setup_blueprints.sh
```

**Resources created:**
- `CompositionDefinition: portal-blueprint-page` (krateo-system)
- `PortalBlueprintPage: github-scaffolding-with-composition-page` (demo-system)

#### `initialize_krateo.sh` - Orchestrator
Runs all three installation steps in sequence. Recommended for reproducible deployments.

```bash
./setup/initialize_krateo.sh
```

## 📝 Configuration

Edit `config/common.conf` to customize installation:

```bash
KRATEO_VERSION="3.0.0-rc4"
KRATEO_PROFILE="debug"
KRATEO_SYSTEM_NAMESPACE="krateo-system"
DEMO_SYSTEM_NAMESPACE="demo-system"
```

## 📋 Examples

### Scenario 1: Fresh Installation
```bash
./setup/create_kind_cluster.sh prod-cluster
./setup/initialize_krateo.sh           # Runs all 3 installation scripts
./stresstest/stresstest_setup.sh
```

### Scenario 2: Upgrade Only Blueprints
```bash
./setup/setup_blueprints.sh            # Skip providers, just update blueprints
```

### Scenario 3: Debug One Component
```bash
# Install core only, skip rest
./setup/install_krateo_core.sh

# Debug/fix issues, then continue
./setup/install_krateo_providers.sh
./setup/setup_blueprints.sh
```

## � Monitoring & Troubleshooting

### Check Installation Status
```bash
./scripts/check_krateo_status.sh
```

This shows:
- Namespace status
- Krateo core installation state
- Helm releases and their status
- CompositionDefinition readiness
- Admin credentials

### Cleanup Stuck Providers
If installation fails with "cannot reuse a name that is still in use":

```bash
./cleanup_providers.sh --force
./install_krateo_providers.sh  # Retry
```

### View Full Troubleshooting Guide
See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for:
- Common issues and solutions
- Diagnostic commands
- Recovery procedures
- Debug information collection

## 📚 Reference

- [Krateo Documentation](https://docs.krateo.io)
- [krateoctl Reference](https://docs.krateo.io/getting-started/install-krateoctl)
Works with KIND, EKS, GKE, AKS.

### kind-portal-gh-scaffolding.sh
```bash
./setup/kind-portal-gh-scaffolding.sh [cluster-name] [image]
```

### Stress Testing
```bash
./stresstest/stresstest_setup.sh
./stresstest/stresstest_create_resources.sh 1 100
./stresstest/stresstest_composition_status.sh
./stresstest/monitor.sh &
./stresstest/setup_monitoring.sh
```

## ⚙️ Configuration

### common.conf (Platform)
```bash
KRATEO_VERSION="3.0.0-rc3"
KRATEO_SYSTEM_NAMESPACE="krateo-system"
KRATEO_PORTAL_PORT=30080
KRATEO_AUTHN_PORT=30082
KRATEO_EVENTS_PORT=30083
```

### config/stresstest.conf (Tests)
```bash
STRESSTEST_NAMESPACE="stresstest-system"
DEFAULT_RESOURCE_START=1
DEFAULT_RESOURCE_END=5
MONITORING_INTERVAL=60
```

## 🌍 Multi-Cluster

### EKS
```bash
kubectl config use-context my-eks-cluster
./setup/initialize_krateo.sh
./stresstest/stresstest_setup.sh
```

### GKE
```bash
gcloud container clusters get-credentials my-gke-cluster
./setup/initialize_krateo.sh
./stresstest/stresstest_setup.sh
```

### AKS
```bash
az aks get-credentials --resource-group myRg --name myAks
./setup/initialize_krateo.sh
./stresstest/stresstest_setup.sh
```

## 🔍 Verify

### Check Syntax
```bash
bash -n initialize_krateo.sh
bash -n stresstest/stresstest_*.sh
```

### Check Resources
```bash
kubectl get compositiondefinitions -n krateo-system
kubectl get portalblueprintintpages -n demo-system
kubectl get deployments -n krateo-system
```

## 🎯 Service Access

- Portal: http://localhost:30080
- AuthN: http://localhost:30082
- Snowplow: http://localhost:30081
- Events API: http://localhost:30083
4. Verify cluster: `kubectl cluster-info`