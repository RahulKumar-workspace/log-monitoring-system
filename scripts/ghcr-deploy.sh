#!/bin/bash

# =============================================================================
# GHCR Deploy Script
# =============================================================================
# This script deploys the application using images from GitHub Container
# Registry (GHCR) instead of locally-built images.
#
# It is the LOCAL equivalent of what the CD GitHub Action does.
#
# Usage:
#   ./scripts/ghcr-deploy.sh                        # deploy dev overlay
#   ./scripts/ghcr-deploy.sh prod                   # deploy prod overlay
#   IMAGE_TAG=sha-abc1234 ./scripts/ghcr-deploy.sh  # deploy specific commit
#
# Prerequisites:
#   - kubectl configured and cluster running
#   - Docker logged in to ghcr.io (for pulling private images)
#   - Git remote 'origin' pointing to your GitHub repo
# =============================================================================

set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Determine overlay (dev or prod)
OVERLAY="${1:-dev}"
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}    GHCR Deploy — ${OVERLAY} overlay                            ${NC}"
echo -e "${CYAN}================================================================${NC}"

# -------------------------------------------------------
# 1. Determine GHCR image path from git remote
# -------------------------------------------------------
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [ -z "$REMOTE_URL" ]; then
    echo -e "${RED}Error: No git remote 'origin'. Set it with:${NC}"
    echo -e "  git remote add origin https://github.com/YOUR_USER/log-monitoring-system.git"
    exit 1
fi

# Extract owner/repo, lowercase (GHCR requires lowercase)
REPO_PATH=$(echo "$REMOTE_URL" | sed -E 's#(https://github.com/|git@github.com:)##' | sed 's/.git$//' | tr '[:upper:]' '[:lower:]')

# Image tag: use IMAGE_TAG env var, or fall back to latest git SHA, or "latest"
if [ -n "${IMAGE_TAG}" ]; then
    TAG="${IMAGE_TAG}"
elif git rev-parse --short HEAD &>/dev/null; then
    TAG="sha-$(git rev-parse --short HEAD)"
else
    TAG="latest"
fi

BACKEND_IMAGE="ghcr.io/${REPO_PATH}/backend:${TAG}"
FRONTEND_IMAGE="ghcr.io/${REPO_PATH}/frontend:${TAG}"

echo -e "  Backend:  ${CYAN}${BACKEND_IMAGE}${NC}"
echo -e "  Frontend: ${CYAN}${FRONTEND_IMAGE}${NC}"
echo -e "  Overlay:  ${YELLOW}k8s/overlays/${OVERLAY}${NC}"

# -------------------------------------------------------
# 2. Update Kustomize images in the overlay
# -------------------------------------------------------
echo -e "\n${YELLOW}Updating Kustomize image references...${NC}"

# Use kustomize edit to dynamically set the GHCR image+tag in the overlay
pushd "k8s/overlays/${OVERLAY}" > /dev/null

# This replaces the `images:` block in kustomization.yaml
kubectl kustomize edit set image "backend=${BACKEND_IMAGE}" 2>/dev/null || \
  kustomize edit set image "backend=${BACKEND_IMAGE}" 2>/dev/null || \
  echo -e "${YELLOW}  kustomize CLI not found, falling back to kubectl apply with set image${NC}"

kubectl kustomize edit set image "frontend=${FRONTEND_IMAGE}" 2>/dev/null || \
  kustomize edit set image "frontend=${FRONTEND_IMAGE}" 2>/dev/null || true

popd > /dev/null

# -------------------------------------------------------
# 3. Apply the overlay
# -------------------------------------------------------
echo -e "\n${YELLOW}Applying Kustomize overlay...${NC}"
kubectl apply -k "k8s/overlays/${OVERLAY}"

# -------------------------------------------------------
# 4. Update deployment images (belt-and-suspenders approach)
# -------------------------------------------------------
echo -e "\n${YELLOW}Setting deployment images...${NC}"
kubectl set image deployment/backend-deployment "backend=${BACKEND_IMAGE}" \
    -n log-monitoring-app 2>/dev/null || true
kubectl set image deployment/frontend-deployment "frontend=${FRONTEND_IMAGE}" \
    -n log-monitoring-app 2>/dev/null || true

# -------------------------------------------------------
# 5. Wait for rollout
# -------------------------------------------------------
echo -e "\n${YELLOW}Waiting for rollout to complete...${NC}"
kubectl rollout status deployment/backend-deployment -n log-monitoring-app --timeout=120s
kubectl rollout status deployment/frontend-deployment -n log-monitoring-app --timeout=120s

# -------------------------------------------------------
# 6. Verify
# -------------------------------------------------------
echo -e "\n${YELLOW}Verifying deployment...${NC}"
kubectl get pods -n log-monitoring-app -o wide

echo -e "\n${CYAN}================================================================${NC}"
echo -e "${GREEN}    ✅ GHCR Deploy Complete (${OVERLAY})${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "  Images deployed from GHCR with tag: ${GREEN}${TAG}${NC}"
echo -e "  Access Grafana:  ${CYAN}http://localhost:30000${NC}"
echo -e "  Access App:      ${CYAN}http://log-monitoring.local${NC}"
echo -e "${CYAN}================================================================${NC}"
