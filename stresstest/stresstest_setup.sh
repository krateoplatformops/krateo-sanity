#!/bin/bash

PROJECT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )


kubectl create namespace stresstest-system
kubectl create ns metrics-server

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.5.0/components.yaml
kubectl patch -n kube-system deployment metrics-server --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'


# Install deps for GithubScaffolding
helm repo add marketplace https://marketplace.krateo.io
helm repo update marketplace
helm install github-provider-kog-repo marketplace/github-provider-kog-repo --namespace krateo-system --create-namespace --wait --version 1.0.0
helm install git-provider krateo/git-provider --namespace krateo-system --create-namespace --wait --version 0.10.1
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo
helm install argocd argo/argo-cd --namespace krateo-system --create-namespace --version 8.0.17

# Loop until the CRD repoes.github.ogen.krateo.io is ready
while true; do
  kubectl get crd repoes.github.ogen.krateo.io &> /dev/null
  if [ $? -eq 0 ]; then
    echo "CRD repoes.github.ogen.krateo.io is ready"
    break
  else
    echo "Waiting for CRD repoes.github.ogen.krateo.io to be ready..."
    sleep 5
  fi
done
