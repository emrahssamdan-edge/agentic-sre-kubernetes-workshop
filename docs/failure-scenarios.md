# EasyTrade Failure Scenarios

EasyTrade includes built-in chaos engineering patterns for testing observability. These simulate real production issues that Edge Delta can detect and surface.

## Available Patterns

| Pattern | Helm Key | Effect |
|---------|----------|--------|
| Database outage | `dbNotResponding` | Simulates DB unresponsiveness on transaction creation |
| High CPU | `highCpuUsage` | Applies CPU limits to broker-service, increases latency |
| Factory crisis | `factoryCrisis` | Stops credit card production pipeline |
| Aggregator slowdown | `ergoAggregatorSlowdown` | Adds delay to 2/5 aggregator-service responses |
| Credit card meltdown | `creditCardMeltdown` | Division by zero error in credit card status endpoint |

## How It Works

EasyTrade uses a **feature-flag-service** to control failure patterns. The **problem-operator** polls the flag service every 5 seconds and applies effects (e.g., patching deployments, scaling resources) when flags change.

## Triggering a Failure Pattern

### Via Helm Upgrade (Recommended)

Toggle patterns using `--set` flags during a Helm upgrade:

```bash
helm upgrade easytrade helm/easytrade -f helm/values-workshop.yaml \
  -n easytrade \
  --set feature-flag-service.problemPatterns.dbNotResponding=true
```

You can enable multiple patterns at once:

```bash
helm upgrade easytrade helm/easytrade -f helm/values-workshop.yaml \
  -n easytrade \
  --set feature-flag-service.problemPatterns.dbNotResponding=true \
  --set feature-flag-service.problemPatterns.creditCardMeltdown=true
```

To disable, set back to `false`:

```bash
helm upgrade easytrade helm/easytrade -f helm/values-workshop.yaml \
  -n easytrade \
  --set feature-flag-service.problemPatterns.dbNotResponding=false \
  --set feature-flag-service.problemPatterns.creditCardMeltdown=false
```

### Via REST API (Alternative)

For quick toggling without a Helm upgrade, port-forward to the reverse proxy:

```bash
kubectl port-forward -n easytrade svc/easytrade-frontendreverseproxy 8080:8080
```

**Enable a pattern:**

```bash
curl -X PUT "http://localhost:8080/feature-flag-service/v1/flags/{PATTERN_ID}/" \
  -H "accept: application/json" \
  -d '{"enabled": true}'
```

**Disable a pattern:**

```bash
curl -X PUT "http://localhost:8080/feature-flag-service/v1/flags/{PATTERN_ID}/" \
  -H "accept: application/json" \
  -d '{"enabled": false}'
```

Replace `{PATTERN_ID}` with: `db_not_responding`, `high_cpu_usage`, `factory_crisis`, `ergo_aggregator_slowdown`, or `credit_card_meltdown`.

> **Note:** REST API changes are ephemeral - they reset when the pod restarts. Helm values are persistent across deploys.

## What to Observe

After enabling a pattern, check Edge Delta for:

- **Database outage** - Connection errors in accountservice, loginservice, offerservice logs
- **High CPU** - Increased latency metrics on broker-service, CPU spike alerts
- **Factory crisis** - Errors in credit-card-order-service, blocked third-party-service calls
- **Aggregator slowdown** - Timeout errors in aggregator-service, increased response times
- **Credit card meltdown** - Division by zero errors in credit-card-order-service logs

---

[Back to README](../README.md)
