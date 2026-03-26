# Krateo Sanity Check 

Framework for validating Krateo installation and stress testing.

## 🚀 Quick Start

### Complete Setup
```bash
./kind-portal-gh-scaffolding.sh
```

### Modular Setup
```bash
./create_kind_cluster.sh my-cluster
./initialize_krateo.sh
./stresstest/stresstest_setup.sh
./stresstest/stresstest_create_resources.sh 1 100
./stresstest/stresstest_composition_status.sh
```

## 📦 Structure

```
krateo-sanity/
├── common.sh                    # Shared utilities (root)
├── common.conf                  # Platform config
├── create_kind_cluster.sh       # KIND cluster creation
├── initialize_krateo.sh         # Krateo initialization
├── kind-portal-gh-scaffolding.sh # Quickstart orchestrator
└── stresstest/
    ├── stresstest.conf         # Test config
    ├── stresstest_setup.sh
    ├── stresstest_create_resources.sh
    ├── stresstest_composition_status.sh
    ├── monitor.sh
    └── setup_monitoring.sh
```

## 🔧 Scripts

### create_kind_cluster.sh
```bash
./create_kind_cluster.sh [cluster-name] [node-image]
./create_kind_cluster.sh my-cluster kindest/node:v1.33.4
```

### initialize_krateo.sh
```bash
./initialize_krateo.sh
```
Works with KIND, EKS, GKE, AKS.

### kind-portal-gh-scaffolding.sh
```bash
./kind-portal-gh-scaffolding.sh [cluster-name] [image]
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

### stresstest/stresstest.conf (Tests)
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
./initialize_krateo.sh
./stresstest/stresstest_setup.sh
```

### GKE
```bash
gcloud container clusters get-credentials my-gke-cluster
./initialize_krateo.sh
./stresstest/stresstest_setup.sh
```

### AKS
```bash
az aks get-credentials --resource-group myRg --name myAks
./initialize_krateo.sh
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