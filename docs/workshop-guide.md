# Workshop Guide: When Kubernetes Apps Break

Step-by-step instructions for the workshop. Follow along at your own pace.

---

## Step 1: Verify Prerequisites (0-5 min)

Make sure all tools are installed:

```bash
docker --version
minikube version
kubectl version --client
helm version
git version
```

Start minikube with enough resources for 19 microservices:

```bash
minikube start --cpus=4 --memory=8192
```

> **Tip:** If your machine has more resources, feel free to increase these values. The application benefits from extra CPU.

Verify the cluster is running:

```bash
kubectl cluster-info
```

---

## Step 2: Deploy EasyTrade (5-10 min)

Clone this repo (if you haven't already) and deploy:

```bash
git clone https://github.com/emrahssamdan-edge/agentic-sre-kubernetes-workshop.git
cd agentic-sre-kubernetes-workshop
```

Build the Helm chart dependencies and install:

```bash
helm dependency build helm/easytrade
helm install easytrade helm/easytrade -f helm/values-workshop.yaml -n easytrade --create-namespace
```

Watch pods come up:

```bash
kubectl get pods -n easytrade -w
```

Wait until all pods show `Running` status. This typically takes 2-3 minutes. The `db` pod may take the longest since it initializes the SQL Server database.

> **Troubleshooting:** If pods are stuck in `Pending`, check if minikube has enough resources: `kubectl describe pod <pod-name> -n easytrade`

Once all pods are running, verify the application is accessible:

```bash
kubectl port-forward -n easytrade svc/easytrade-frontendreverseproxy 8080:8080
```

Open [http://localhost:8080](http://localhost:8080) in your browser. You should see the EasyTrade trading platform. Login with `demouser` / `demopass`.

> Press `Ctrl+C` to stop port-forwarding when done. The app continues running in the cluster.

---

## Step 3: Install Edge Delta Agent (10-15 min)

### Create your Edge Delta account

1. Go to [app.edgedelta.com](https://app.edgedelta.com) and sign up for a free account
2. Once logged in, navigate to **Pipelines** in the left sidebar
3. Create a new pipeline or use the default one
4. Copy your **API Key** from the pipeline settings

### Install the agent

```bash
helm repo add edgedelta https://edgedelta.github.io/charts
helm repo update

helm install edgedelta edgedelta/edgedelta \
  -n edgedelta --create-namespace \
  --set secretApiKey.value=YOUR_ED_API_KEY
```

Replace `YOUR_ED_API_KEY` with the API key you copied from Edge Delta.

Verify the agent is running:

```bash
kubectl get pods -n edgedelta
```

You should see the Edge Delta agent pod(s) in `Running` status.

---

## Step 4: Verify Healthy Baseline (15-18 min)

Go back to [app.edgedelta.com](https://app.edgedelta.com). Within a minute or two, you should start seeing:

- **Logs** flowing in from all 19 EasyTrade services
- **Kubernetes metadata** attached to each log line (pod name, namespace, labels)
- A healthy baseline with normal application behavior

Take a minute to explore the Edge Delta UI:
- Browse logs from different services
- Notice the automatic pattern detection and grouping
- This is the "normal" state - remember what it looks like

---

## Step 5: Trigger Failure Scenario #1 - Database Outage (18-23 min)

Now let's break something. Enable the database outage pattern:

```bash
helm upgrade easytrade helm/easytrade -f helm/values-workshop.yaml \
  -n easytrade \
  --set feature-flag-service.problemPatterns.dbNotResponding=true
```

This simulates the database becoming unresponsive. The feature-flag-service restarts with the new flag, and the problem-operator detects it within 5 seconds.

### What happens

- The `accountservice`, `loginservice`, and `offerservice` start throwing database connection errors
- The load generator continues making requests, so error volume is significant
- Log patterns change dramatically from the healthy baseline

### What to observe in Edge Delta

1. Watch for new **agentic investigation threads** appearing - Edge Delta automatically detects the anomaly
2. Notice how related errors across multiple services are **grouped together** into a single investigation
3. Click into the investigation thread to see the AI-generated analysis
4. **Ask follow-up questions** in the thread - for example:
   - "Which services are affected?"
   - "When did this start?"
   - "What changed before the errors began?"

---

## Step 6: Trigger Failure Scenario #2 - Credit Card Meltdown (23-28 min)

Let's add another failure on top of the first:

```bash
helm upgrade easytrade helm/easytrade -f helm/values-workshop.yaml \
  -n easytrade \
  --set feature-flag-service.problemPatterns.dbNotResponding=true \
  --set feature-flag-service.problemPatterns.creditCardMeltdown=true
```

This triggers a division-by-zero error in the credit card order service.

### What to observe

- A **new investigation thread** appears for the credit card service errors
- Edge Delta distinguishes between the two different failure patterns
- The database outage thread continues tracking that issue separately
- Ask questions to understand the relationship (or lack thereof) between the two failures

---

## Step 7: Restore and Clean Up (28-30 min)

Disable all failure patterns:

```bash
helm upgrade easytrade helm/easytrade -f helm/values-workshop.yaml \
  -n easytrade \
  --set feature-flag-service.problemPatterns.dbNotResponding=false \
  --set feature-flag-service.problemPatterns.creditCardMeltdown=false
```

Watch the recovery in Edge Delta - notice how the investigation threads reflect the resolution.

### Full cleanup

When you're done:

```bash
helm uninstall edgedelta -n edgedelta
helm uninstall easytrade -n easytrade
kubectl delete namespace easytrade edgedelta
minikube stop
minikube delete
```

---

## Bonus: Try Other Failure Patterns

If you have extra time, try these scenarios:

```bash
# High CPU on broker-service - causes latency spikes
--set feature-flag-service.problemPatterns.highCpuUsage=true

# Factory crisis - breaks the credit card production pipeline
--set feature-flag-service.problemPatterns.factoryCrisis=true

# Aggregator slowdown - adds delays to aggregator responses
--set feature-flag-service.problemPatterns.ergoAggregatorSlowdown=true
```

See [Failure Scenarios](failure-scenarios.md) for details on each pattern.

---

## Troubleshooting

**Pods stuck in Pending:**
```bash
kubectl describe pod <pod-name> -n easytrade
# Usually means minikube needs more CPU/memory
minikube stop
minikube start --cpus=4 --memory=8192
```

**Pods in CrashLoopBackOff:**
```bash
kubectl logs <pod-name> -n easytrade
# The db pod may take longer to start. Other services retry connections automatically.
```

**Edge Delta not showing logs:**
```bash
kubectl logs -n edgedelta -l app=edgedelta
# Check that the API key is correct
```

**Can't pull images:**
The images come from a public registry (`europe-docker.pkg.dev/dynatrace-demoability/docker/easytrade`). If you're behind a corporate firewall, you may need to configure proxy settings in Docker Desktop.
