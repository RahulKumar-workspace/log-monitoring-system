#!/bin/bash

# Kubernetes Cleanup Script
# Removes the entire dev overlay (app + monitoring + ingress) from the cluster.
# Works with Minikube, Kind, Docker Desktop – any cluster where the overlay was applied.

set -e

echo "\n=== Kubernetes Observability Platform Cleanup ==="

# Delete resources using the same overlay path that was applied
kubectl delete -k k8s/overlays/dev || true

# Optionally, delete the local images (if you no longer need them locally)
# Uncomment the lines below to remove Docker images:
# docker rmi backend:latest frontend:latest || true

echo "\n✅ Cleanup complete. All manifests removed from the cluster."
