# Krateo Sanity Check 

Framework for validating Krateo installation and stress testing.

> [!WARNING]
> This repository contains scripts and configurations intended for development, testing, and validation purposes only. These scripts should NOT be used in production environments. Use at your own risk. For production deployments, follow the official Krateo deployment documentation and implement appropriate security, monitoring, and backup strategies.

## Quick Start

### Complete Setup (All-in-One)
```bash
# Run integrated quickstart
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
# Execute all installation steps in sequence
./setup/initialize_krateo.sh
```

## Installation Scripts

### Setup Directory (`setup/`)

Creates the Kubernetes infrastructure and deploys Krateo platform components in sequence.

#### `create_kind_cluster.sh` - Create Kubernetes Cluster

Provisions a local Kubernetes cluster using KIND with Krateo-specific port mappings configured.
```bash
# Create a new KIND cluster with specified name and node image
./setup/create_kind_cluster.sh [cluster-name] [node-image]
# Example:
./setup/create_kind_cluster.sh my-cluster kindest/node:v1.33.4
```

#### `install_krateo_core.sh` - Install Krateo Core Platform

Deploys the Krateo platform core components (authentication, events, portal) using the krateoctl CLI.

**Prerequisites:**
- `krateoctl` must be installed on PATH

```bash
# Deploy Krateo core platform
./setup/install_krateo_core.sh
```

**What it does:**
- Creates `krateo-system` namespace
- Verifies krateoctl availability  
- Runs `krateoctl install apply` with configured profile
- Retrieves admin credentials

**Monitoring Profile:**
For OpenTelemetry-enabled deployment, use the monitoring profile:
```bash
# Deploy with monitoring support
KRATEO_PROFILE="monitoring" ./setup/install_krateo_core.sh
```

#### `install_krateo_providers.sh` - Install Composition Providers

Sets up composition providers and infrastructure components needed for blueprint management.

**Prerequisites:**
- Krateo core must be installed (run `install_krateo_core.sh` first)

```bash
# Install composition providers
./setup/install_krateo_providers.sh
```

**Providers installed:**
- `github-provider-kog-repo` - GitHub scaffolding provider
- `git-provider` - Git operations provider  
- `argocd` - GitOps continuous deployment

#### `setup_blueprints.sh` - Setup Blueprint Definitions

Registers composition definitions and creates portal blueprint page instances for the Krateo UI.

**Prerequisites:**
- All providers must be installed (run `install_krateo_providers.sh` first)

```bash
# Register blueprints and compositions
./setup/setup_blueprints.sh
```

**Resources created:**
- `CompositionDefinition: portal-blueprint-page` (krateo-system)
- `PortalBlueprintPage: github-scaffolding-with-composition-page` (demo-system)

#### `initialize_krateo.sh` - Orchestrator

Automates the complete installation workflow by executing all setup scripts in the correct order.

```bash
# Execute all installation steps in sequence
./setup/initialize_krateo.sh
```

## Configuration

Edit `config/common.conf` to customize installation:

```bash
KRATEO_VERSION="3.0.0-rc8"
KRATEO_PROFILE="debug"
KRATEO_SYSTEM_NAMESPACE="krateo-system"
DEMO_SYSTEM_NAMESPACE="demo-system"
```

## Examples

### Scenario 1: Fresh Installation
```bash
# Create cluster
./setup/create_kind_cluster.sh prod-cluster
# Run all 3 installation scripts
./setup/initialize_krateo.sh
# Setup stress test environment
./stresstest/stresstest_setup.sh
```

### Scenario 2: Upgrade Only Blueprints
```bash
# Skip providers, just update blueprints
./setup/setup_blueprints.sh
```

### Scenario 3: Debug One Component
```bash
# Install core only, skip rest
./setup/install_krateo_core.sh

# Debug/fix issues, then continue
./setup/install_krateo_providers.sh
./setup/setup_blueprints.sh
```

## Monitoring & Troubleshooting

### Platform Monitoring Setup

For comprehensive OpenTelemetry monitoring of Krateo platform components (events, metrics, traces), refer to the dedicated [Monitoring Documentation](monitoring/monitoring.md).

**Enable event and resource monitoring:**

Deploy Krateo with OpenTelemetry support using the monitoring profile:
```bash
# Install Krateo with event/resource monitoring enabled
KRATEO_PROFILE="monitoring" ./setup/install_krateo_core.sh
```

**What this enables:**
- `deviser`, `events-ingester`, and `events-presenter` services with OpenTelemetry enabled
- OpenTelemetry Collector running in monitoring namespace
- Kube-Prometheus-Stack deployed (Prometheus + Grafana)

**Access monitoring dashboards:**
- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000` (credentials: admin/admin)

For detailed setup instructions, environment configuration, and troubleshooting, see [Monitoring Documentation](monitoring/monitoring.md).

### Stress Testing with Monitoring

Run performance and stability tests on the Krateo platform with integrated monitoring visibility.

**Setup and execute stress test with monitoring:**
```bash
# Setup stress test environment
./stresstest/stresstest_setup.sh
# Create test resources (from resource 1 to 100)
./stresstest/stresstest_create_resources.sh 1 100
# Check composition status during stress test
./stresstest/stresstest_composition_status.sh
# Start real-time cluster monitoring (background process)
./stresstest/monitor.sh &
# View stress test monitoring metrics
./stresstest/stresstest_cluster_status.sh
```

**Prerequisites:**
- Platform monitoring stack already deployed (see Platform Monitoring Setup above)
- Stress test namespace created with `stresstest_setup.sh`

### Check Installation Status

Verifies that all Krateo components are properly installed and ready.

```bash
# Verify installation status
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
# Force cleanup of provider resources
./cleanup_providers.sh --force
# Retry provider installation
./install_krateo_providers.sh
```