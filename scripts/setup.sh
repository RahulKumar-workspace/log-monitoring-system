#!/bin/bash

# Setup Script for the Cloud-Native Observability Dashboard
# This script builds and starts all microservices and monitoring components locally.

set -e

# Define console output colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0;m' # No Color

echo -e "${CYAN}========================================================================${NC}"
echo -e "${CYAN}    Initializing Log Monitoring System & Observability Stack            ${NC}"
echo -e "${CYAN}========================================================================${NC}"

# Check if Docker command line is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed. Please install Docker and retry.${NC}"
    exit 1
fi

# Verify if Docker daemon is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker daemon is not running. Please launch Docker Desktop.${NC}"
    exit 1
fi

# Locate docker-compose command
COMPOSE_CMD=""
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}Error: Neither 'docker compose' nor 'docker-compose' was found.${NC}"
    exit 1
fi

# Navigate to the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo -e "\n${YELLOW}Step 1: Building and launching docker-compose services...${NC}"
$COMPOSE_CMD -f docker/docker-compose.yml up --build -d

echo -e "\n${GREEN}✔ All containers started successfully in detached mode!${NC}"
echo -e "${CYAN}========================================================================${NC}"
echo -e "${CYAN}    PORT MAP & SERVICE DASHBOARD ACCESS                                 ${NC}"
echo -e "${CYAN}========================================================================${NC}"
echo -e "   🚀  React Web App (Frontend):   ${GREEN}http://localhost:8080${NC}"
echo -e "   🔌  FastAPI Service (Backend):  ${GREEN}http://localhost:8000${NC}"
echo -e "   🩺  Backend Health Probe:       ${GREEN}http://localhost:8000/health${NC}"
echo -e "   📊  Prometheus Raw Metrics:     ${GREEN}http://localhost:8000/metrics${NC}"
echo -e "   📈  Prometheus Dashboard:      ${GREEN}http://localhost:9090${NC}"
echo -e "   🪵  Loki Server status:         ${GREEN}http://localhost:3100/ready${NC}"
echo -e "   🎨  Grafana UI (Visualizer):    ${GREEN}http://localhost:3000${NC}"
echo -e "       ┗ Credentials: User: ${YELLOW}admin${NC} | Password: ${YELLOW}admin${NC}"
echo -e "${CYAN}========================================================================${NC}"
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "1. Open ${CYAN}http://localhost:8080${NC} in your browser and click button logs."
echo -e "2. Open Grafana, sign in, and head to dashboards (FastAPI Observability)."
echo -e "3. To simulate automatic high traffic, run: ${CYAN}./scripts/generate-logs.sh${NC}"
echo -e "4. To stop the environment, run: ${CYAN}docker compose -f docker/docker-compose.yml down -v${NC}"
echo -e "${CYAN}========================================================================${NC}"
