# Cloud-Native DevOps Log Monitoring System

A production-style starter repository demonstrating modern DevOps, containerization, orchestration, and observability practices. 

This repository serves as a boilerplate for a cloud-native microservices architecture equipped with an end-to-end monitoring and structured logging pipeline.

---

## Technical Stack

- **Frontend**: React (Vite) styled with sleek glassmorphism vanilla CSS
- **Backend**: Python FastAPI with Prometheus auto-instrumentation
- **Containerization**: Docker & Docker Compose
- **Orchestration**: Kubernetes (cloud-agnostic NodePort / ClusterIP setup)
- **Monitoring**: Prometheus (metrics scraping) + Grafana (visualizations)
- **Logging**: Loki (log aggregation) + Fluent Bit (log shipping)
- **CI/CD**: GitHub Actions (linting, multi-architecture build, tagging)
- **Cloud Compatibility**: Designed for seamless migration to AWS (EKS, CloudWatch, Managed Prometheus/Grafana)

---

## Folder Structure

```text
log-monitoring-system/
├── .github/workflows/   # CI/CD pipelines (GitHub Actions)
├── backend/             # FastAPI code, requirements, Docker config
├── frontend/            # React + Vite source, Nginx configs, Docker config
├── docker/              # Docker Compose local development config
├── k8s/                 # Cloud-agnostic Kubernetes manifests
├── monitoring/          # Configs for Prometheus, Grafana, Loki, Fluent Bit
├── scripts/             # Setup and traffic simulation helper scripts
├── docs/                # Detailed architecture & AWS deployment specs
└── README.md            # You are here
```

---

## Observability Architecture Overview

The application telemetry flows through two distinct, decoupled pipelines:

1. **Metrics Pipeline**: 
   `FastAPI Backend (/metrics)` ──> `Prometheus Scraper` ──> `Grafana Visualizer`
2. **Logging Pipeline**: 
   `FastAPI Backend (JSON logs)` ──> `Shared Volume` ──> `Fluent Bit Shipper` ──> `Loki Aggregator` ──> `Grafana Viewer`

For a detailed visual mapping and technical breakdown, view [docs/architecture.md](file:///Users/krahul/Desktop/log-monitoring-system/docs/architecture.md).

---

## Local Development Quickstart

### Prerequisites
Make sure you have the following installed:
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (v20.10+ recommended)
- Bash terminal (Linux/macOS)

### 1. Launch the Stack
Run the automated initialization helper script:
```bash
./scripts/setup.sh
```
This builds the custom local Docker images (ensuring compatibility on both Intel Macs and **Apple Silicon ARM64 M-Series Macs**) and brings up the containers.

Once completed, the script prints out active ports and dashboard endpoints:
- **React Frontend**: [http://localhost:8080](http://localhost:8080)
- **FastAPI Backend**: [http://localhost:8000](http://localhost:8000)
- **Grafana Dashboards**: [http://localhost:3000](http://localhost:3000) (default credentials: `admin` / `admin`)
- **Prometheus UI**: [http://localhost:9090](http://localhost:9090)

### 2. Generate Simulated Log Traffic
Open the React Frontend Dashboard at [http://localhost:8080](http://localhost:8080) to manually trigger health checks and generate logs at various severities (`INFO`, `WARNING`, `ERROR`).

Alternatively, trigger automatic high-traffic simulations in the background:
```bash
./scripts/generate-logs.sh http://localhost:8000 100 0.2
```
This script fires 100 requests to the backend with a 0.2-second delay.

### 3. View Logs & Metrics in Grafana
1. Go to [http://localhost:3000](http://localhost:3000) and sign in (`admin`/`admin`).
2. Search for the pre-configured **FastAPI Observability Dashboard** in Grafana's search bar.
3. Observe live panels for:
   - Request volumes and average latencies (scraped from Prometheus).
   - Real-time log streams containing correlation IDs and exception backtraces (shipped by Fluent Bit to Loki).

### 4. Tearing Down the Stack
To stop and clean up all resources, run:
```bash
docker compose -f docker/docker-compose.yml down -v
```

---

## Kubernetes Orchestration Guide

This repository contains clean, modular Kubernetes manifests in [k8s/](file:///Users/krahul/Desktop/log-monitoring-system/k8s/).

To spin up the services inside a local cluster (e.g. Minikube or Kind):

```bash
# 1. Create the dedicated namespace
kubectl apply -f k8s/namespace.yaml

# 2. Deploy the configurations
kubectl apply -f k8s/configmap.yaml

# 3. Deploy the backend API
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml

# 4. Deploy the frontend static server
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/frontend-service.yaml
```

### Key Orchestration Design Patterns:
- **Decoupled Configuration**: Deployment manifests consume properties using `ConfigMaps` to dynamically load log levels, target base URLs, and parameters without modifying application images.
- **Self-Healing Probes**: Configured with `readinessProbes` and `livenessProbes` pointing to `/health` (backend) and `/` (frontend). Kubernetes automatically restarts deadlocked containers and redirects traffic away from booting pods.
- **Resource Boundary Control**: Strict CPU and memory limits ensure pods do not trigger node-wide memory depletion.
- **Local Access via NodePort**: The frontend service is exposed on port `30080` to enable local testing without provisioning cloud load balancers.

---

## Production AWS Deployment Plan

For deploying this repository into an AWS production environment:
1. Migrate container images to **Amazon ECR**.
2. Run microservices inside **Amazon EKS** (Elastic Kubernetes Service) managed node groups.
3. Replace local Prometheus/Grafana with **Amazon Managed Prometheus (AMP)** and **Amazon Managed Grafana (AMG)**.
4. Run **AWS for Fluent Bit** as a DaemonSet to stream logs to **Amazon CloudWatch** or **Amazon OpenSearch**.
5. Set up the **AWS ALB Ingress Controller** to manage TLS certificates and route user queries securely.

A detailed setup workflow and YAML mapping examples can be reviewed in [docs/aws-deployment.md](file:///Users/krahul/Desktop/log-monitoring-system/docs/aws-deployment.md).
