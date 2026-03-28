# When Kubernetes Apps Break: Agentic SRE in Action

A hands-on workshop where you deploy a 19-microservice trading platform on minikube, intentionally break it, and use Edge Delta's agentic SRE workflows to investigate failures - instead of manually digging through logs.

## What You'll Learn

- Deploy a realistic microservice application (EasyTrade) to a local Kubernetes cluster
- Trigger real-world failure patterns: database outages, error spikes, anomalous log behavior
- Use Edge Delta's agentic investigation threads to analyze and troubleshoot issues
- Ask follow-up questions about operational signals instead of manually searching logs

## Prerequisites

**Knowledge:** Basic understanding of Kubernetes concepts (pods, deployments, services) and comfort with the command line.

**Tools - install before the workshop:**

| Tool | Install |
|------|---------|
| Docker Desktop or colima | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) or `brew install colima docker` |
| minikube | `brew install minikube` or [minikube.sigs.k8s.io/docs/start](https://minikube.sigs.k8s.io/docs/start/) |
| kubectl | `brew install kubectl` or installed with Docker Desktop |
| Helm | `brew install helm` or [helm.sh/docs/intro/install](https://helm.sh/docs/intro/install/) |
| Git | `brew install git` or [git-scm.com](https://git-scm.com/) |
| Python 3 + pymssql | `pip3 install pymssql` (for database setup) |

> **Apple Silicon Macs (M1/M2/M3/M4):** The app images are x86_64. We recommend **colima** as the container runtime - it handles cross-architecture emulation well. See the [Workshop Guide](docs/workshop-guide.md) for details.

No prior experience with AI-driven or agentic systems is required.

## Workshop Flow (30 minutes)

| Step | Time | What You'll Do |
|------|------|----------------|
| 1 | 0-5 min | Verify prerequisites, clone repo, start minikube |
| 2 | 5-10 min | Deploy EasyTrade to your local cluster |
| 3 | 10-15 min | Create a free Edge Delta account, install the observability agent |
| 4 | 15-18 min | Verify healthy baseline in Edge Delta |
| 5 | 18-23 min | Trigger failure scenario #1 - observe agentic investigation |
| 6 | 23-28 min | Trigger failure scenario #2 - ask follow-up questions |
| 7 | 28-30 min | Wrap-up and Q&A |

## Quick Start

Detailed instructions for each step are in the [Workshop Guide](docs/workshop-guide.md).

```bash
# 1. Clone the repo
git clone https://github.com/emrahssamdan-edge/agentic-sre-kubernetes-workshop.git
cd agentic-sre-kubernetes-workshop

# 2. Start container runtime and minikube
# If using colima (recommended for Apple Silicon):
colima start --cpu 4 --memory 8 --disk 30
minikube start --driver=docker --cpus=3 --memory=7600

# 3. Deploy the application
helm dependency build helm/easytrade
helm install easytrade helm/easytrade -f helm/values-workshop.yaml -n easytrade --create-namespace

# 4. Wait for pods to be ready (takes 3-5 minutes)
kubectl get pods -n easytrade -w

# 5. Create the application database (one-time setup)
kubectl port-forward -n easytrade svc/easytrade-db 1433:1433 &
python3 -c "
import pymssql
conn = pymssql.connect(server='localhost', user='sa', password='StrongPass1234', port=1433)
conn.autocommit(True)
conn.cursor().execute('CREATE DATABASE TradeManagement')
print('Database created')
conn.close()
"
kill %1
kubectl rollout restart deployment -n easytrade

# 6. Install Edge Delta agent (replace with your API key)
helm repo add edgedelta https://helm.edgedelta.com && helm repo update
helm upgrade edgedelta edgedelta/edgedelta -i \
  --version 2.13.0 --reuse-values \
  --set watcherProps.enabled=false \
  --set secretApiKey.value=YOUR_ED_API_KEY \
  -n edgedelta --create-namespace

# 7. Trigger a failure
helm upgrade easytrade helm/easytrade -f helm/values-workshop.yaml \
  -n easytrade \
  --set feature-flag-service.problemPatterns.dbNotResponding=true
```

## Application Architecture

EasyTrade is a multi-service trading platform with 19 microservices including a frontend, backend APIs, database, message queue, and a built-in load generator. It produces realistic telemetry - logs, metrics, and traces.

For details, see [Architecture](docs/architecture.md).

## Failure Scenarios

| Pattern | What Breaks | What You'll See in Logs |
|---------|-------------|------------------------|
| Database Outage | DB stops responding to transactions | Connection errors in accountservice, loginservice, offerservice |
| High CPU | broker-service gets CPU-throttled | Increased latency, CPU spike alerts |
| Factory Crisis | Credit card production pipeline stops | Errors in credit-card-order-service, blocked third-party calls |
| Aggregator Slowdown | 2 of 5 aggregator responses delayed | Timeout errors, increased response times |
| Credit Card Meltdown | Division by zero in credit card endpoint | Exception stack traces in credit-card-order-service |

For details, see [Failure Scenarios](docs/failure-scenarios.md).

## Cleanup

```bash
helm uninstall edgedelta -n edgedelta
helm uninstall easytrade -n easytrade
minikube stop
minikube delete
```

## Resources

- [Edge Delta](https://www.edgedelta.com) - Agentic observability platform
- [EasyTrade](https://github.com/Dynatrace/easytrade) - Original demo application by Dynatrace
- [Workshop Guide](docs/workshop-guide.md) - Detailed step-by-step instructions
