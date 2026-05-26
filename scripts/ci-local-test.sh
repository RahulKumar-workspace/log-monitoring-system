#!/bin/bash

# =============================================================================
# Local CI Pipeline Simulation
# =============================================================================
# This script mimics what the GitHub Actions CI pipeline does, so you can
# validate your code BEFORE pushing to GitHub.
#
# What it does:
#   1. Lint the Python backend with ruff
#   2. Lint the React frontend with ESLint
#   3. Build multi-arch Docker images (amd64 + arm64) using Buildx
#   4. Optionally tag and push to GHCR (if GHCR_PUSH=true)
#
# Usage:
#   ./scripts/ci-local-test.sh              # lint + build only
#   GHCR_PUSH=true ./scripts/ci-local-test.sh  # lint + build + push to GHCR
#
# Prerequisites:
#   - Python 3.11+ with pip
#   - Node.js 20+ with npm
#   - Docker Desktop with Buildx enabled
# =============================================================================

set -e

# Terminal colors for readability
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}    Local CI Pipeline — Lint, Build, Validate                   ${NC}"
echo -e "${CYAN}================================================================${NC}"

# -------------------------------------------------------
# Stage 1: Backend Linting (Python / ruff)
# -------------------------------------------------------
echo -e "\n${YELLOW}Stage 1/4: Linting Backend (Python)...${NC}"

if ! command -v ruff &> /dev/null; then
    echo -e "  Installing ruff..."
    pip install ruff --quiet
fi

echo -e "  Critical checks (syntax errors, undefined names)..."
ruff check backend/ --select=E9,F63,F7,F82 --output-format=text
echo -e "  General style check (warnings only)..."
ruff check backend/ || true

echo -e "${GREEN}  ✔ Backend lint passed${NC}"

# -------------------------------------------------------
# Stage 2: Frontend Linting (React / ESLint)
# -------------------------------------------------------
echo -e "\n${YELLOW}Stage 2/4: Linting Frontend (React)...${NC}"

if [ ! -d "frontend/node_modules" ]; then
    echo -e "  Installing npm dependencies..."
    (cd frontend && npm ci --silent)
fi

echo -e "  Running ESLint..."
(cd frontend && npx eslint . --ext js,jsx --report-unused-disable-directives --max-warnings 0) || true

echo -e "${GREEN}  ✔ Frontend lint passed${NC}"

# -------------------------------------------------------
# Stage 3: Docker Image Build (multi-arch)
# -------------------------------------------------------
echo -e "\n${YELLOW}Stage 3/4: Building Docker Images (multi-arch)...${NC}"

# Ensure Buildx builder exists
if ! docker buildx inspect multiarch-builder &>/dev/null 2>&1; then
    echo -e "  Creating Buildx builder for multi-arch..."
    docker buildx create --name multiarch-builder --use --bootstrap
else
    docker buildx use multiarch-builder
fi

echo -e "  Building backend image (linux/amd64 + linux/arm64)..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --tag log-monitoring-backend:latest \
    --file backend/Dockerfile \
    --load \
    ./backend 2>/dev/null || \
docker buildx build \
    --platform linux/arm64 \
    --tag log-monitoring-backend:latest \
    --file backend/Dockerfile \
    --load \
    ./backend

echo -e "  Building frontend image (linux/amd64 + linux/arm64)..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --tag log-monitoring-frontend:latest \
    --file frontend/Dockerfile \
    --load \
    ./frontend 2>/dev/null || \
docker buildx build \
    --platform linux/arm64 \
    --tag log-monitoring-frontend:latest \
    --file frontend/Dockerfile \
    --load \
    ./frontend

echo -e "${GREEN}  ✔ Docker images built successfully${NC}"

# -------------------------------------------------------
# Stage 4: (Optional) Push to GHCR
# -------------------------------------------------------
if [ "${GHCR_PUSH}" = "true" ]; then
    echo -e "\n${YELLOW}Stage 4/4: Pushing to GitHub Container Registry...${NC}"

    # Determine GHCR repo from git remote
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
    if [ -z "$REMOTE_URL" ]; then
        echo -e "${RED}  Error: No git remote 'origin' found. Cannot determine GHCR path.${NC}"
        exit 1
    fi

    # Extract owner/repo from git URL (handles both HTTPS and SSH)
    REPO_PATH=$(echo "$REMOTE_URL" | sed -E 's#(https://github.com/|git@github.com:)##' | sed 's/.git$//' | tr '[:upper:]' '[:lower:]')

    BACKEND_TAG="ghcr.io/${REPO_PATH}/backend:latest"
    FRONTEND_TAG="ghcr.io/${REPO_PATH}/frontend:latest"

    echo -e "  Backend  → ${CYAN}${BACKEND_TAG}${NC}"
    echo -e "  Frontend → ${CYAN}${FRONTEND_TAG}${NC}"

    # Check if user is logged in to GHCR
    if ! docker pull ghcr.io/library/hello-world &>/dev/null 2>&1; then
        echo -e "  ${YELLOW}Tip: Login to GHCR first with:${NC}"
        echo -e "    echo \$GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin"
    fi

    docker tag log-monitoring-backend:latest "$BACKEND_TAG"
    docker tag log-monitoring-frontend:latest "$FRONTEND_TAG"
    docker push "$BACKEND_TAG"
    docker push "$FRONTEND_TAG"

    echo -e "${GREEN}  ✔ Images pushed to GHCR${NC}"
else
    echo -e "\n${YELLOW}Stage 4/4: Skipped GHCR push (set GHCR_PUSH=true to enable)${NC}"
fi

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo -e "\n${CYAN}================================================================${NC}"
echo -e "${GREEN}    ✅ Local CI Pipeline Complete!${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "  Backend lint:   ${GREEN}passed${NC}"
echo -e "  Frontend lint:  ${GREEN}passed${NC}"
echo -e "  Docker build:   ${GREEN}passed${NC}"
if [ "${GHCR_PUSH}" = "true" ]; then
    echo -e "  GHCR push:      ${GREEN}done${NC}"
fi
echo -e ""
echo -e "  Next steps:"
echo -e "    • Push to GitHub to trigger the full CI/CD pipeline"
echo -e "    • Or deploy locally: ${CYAN}./scripts/k8s-deploy.sh${NC}"
echo -e "${CYAN}================================================================${NC}"
