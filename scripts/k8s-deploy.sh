#!/bin/bash

# Kubernetes Local Deployment Automation Script
# Automatically builds application images and deploys the entire dev stack (App + Monitoring)
# compatible with Minikube, Kind, and Docker Desktop Kubernetes.

set -e

# Output colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0;m'

echo -e "${CYAN}========================================================================${NC}"
echo -e "${CYAN}    Kubernetes Observability Platform Local Deployment                  ${NC}"
echo -e "${CYAN}========================================================================${NC}"

# 1. Prerequisite Checks
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

# Detect current cluster context
CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
echo -e "Current Kubernetes context: ${GREEN}$CONTEXT${NC}"

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Determine environment targets (Minikube vs Docker-Desktop/Kind)
IS_MINIKUBE=false
if [[ "$CONTEXT" == *"minikube"* ]]; then
    IS_MINIKUBE=true
    echo -e "Detected ${YELLOW}Minikube${NC} environment."
fi

# 2. Build local Docker images
echo -e "\n${YELLOW}Step 1: Building local application container images...${NC}"

if [ "$IS_MINIKUBE" = true ]; then
    echo -e "Configuring shell to use Minikube's internal Docker daemon..."
    # Point docker client to minikube docker daemon so images are built inside the cluster
    eval $(minikube -p minikube docker-env)
fi

echo -e "Building backend image..."
docker build -t backend:latest ./backend

echo -e "Building frontend image..."
docker build -t frontend:latest ./frontend

if [ "$IS_MINIKUBE" = false ] && [[ "$CONTEXT" == *"kind"* ]]; then
    echo -e "Loading images into Kind cluster..."
    kind load docker-image backend:latest
    kind load docker-image frontend:latest
fi

echo -e "${GREEN}✔ Application images built successfully!${NC}"

# 3. Setup ingress controller details
echo -e "\n${YELLOW}Step 2: Configuring cluster features...${NC}"
if [ "$IS_MINIKUBE" = true ]; then
    echo -e "Enabling Ingress addon in Minikube..."
    minikube addons enable ingress || true
else
    echo -e "Note: For Docker Desktop / Kind, ensure an Ingress Controller (like ingress-nginx) is installed."
    echo -e "If not installed, run: ${CYAN}kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml${NC}"
fi

# 4. Apply manifests using Kustomize overlays
echo -e "\n${YELLOW}Step 3: Deploying base stack and monitoring stack via Kustomize...${NC}"
# kubectl apply -k applies the Kustomization overlay
kubectl apply -k k8s/overlays/dev

echo -e "\n${GREEN}✔ Manifests successfully applied!${NC}"

# 5. Fetch details for access
CLUSTER_IP="127.0.0.1"
if [ "$IS_MINIKUBE" = true ]; then
    CLUSTER_IP=$(minikube ip)
fi

echo -e "${CYAN}========================================================================${NC}"
echo -e "${CYAN}    DEPLOYMENT COMPLETE & SERVICE ACCESS GUIDE                          ${NC}"
echo -e "${CYAN}========================================================================${NC}"
echo -e "Status: Services are spinning up. Run: ${YELLOW}kubectl get pods -A${NC} to check."
echo -e ""
echo -e "1. ${GREEN}App Ingress (Frontend & API)${NC}:"
echo -e "   - Hosts entry required to route domain:"
echo -e "     Add this line to ${YELLOW}/etc/hosts${NC}:"
echo -e "     ${GREEN}$CLUSTER_IP log-monitoring.local${NC}"
echo -e "   - Access App: ${CYAN}http://log-monitoring.local${NC}"
echo -e "     (Frontend routes internally. API routes /health, /metrics, /generate-log)"
echo -e ""
echo -e "2. ${GREEN}Monitoring Dashboard (Grafana)${NC}:"
echo -e "   - NodePort URL: ${CYAN}http://localhost:30000${NC} (or ${CYAN}http://$CLUSTER_IP:30000${NC})"
echo -e "   - Credentials: User: ${YELLOW}admin${NC} | Password: ${YELLOW}admin${NC}"
echo -e ""
echo -e "3. ${GREEN}Prometheus Raw Portal${NC}:"
echo -e "   - NodePort URL: ${CYAN}http://localhost:30090${NC} (or ${CYAN}http://$CLUSTER_IP:30090${NC})"
echo -e ""
echo -e "4. ${GREEN}Teardown Stack${NC}:"
echo -e "   - Run: ${CYAN}./scripts/k8s-cleanup.sh${NC}"
echo -e "${CYAN}========================================================================${NC}"
