#!/bin/bash
set -e

if ! command -v kind &> /dev/null; then
    echo "kind is not installed. Installing..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-$(uname)-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
fi

if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed. Installing..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

echo "Creating Kubernetes cluster with kind..."
kind create cluster --name timbre-cluster --config k8s/kind-config.yaml

echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "Kubernetes cluster is ready!"
echo "To use the cluster, run: kubectl cluster-info --context kind-timbre-cluster" 