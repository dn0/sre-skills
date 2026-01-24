---
name: grafana-mimir
description: Query Grafana Mimir/Prometheus metrics using PromQL. Use when analyzing metrics, container CPU/memory, request rates, error rates, or any time series data via Grafana. Generates Grafana Explore URLs for humans.
---

# Grafana Mimir Skill

Query Mimir/Prometheus metrics via Grafana API using PromQL.

## Requirements

Environment variables:
- `GRAFANA_URL` - Grafana instance URL
- `GRAFANA_API_KEY` - Service account token

## Scripts

### Query metrics (range query)
```bash
./scripts/query.sh DATASOURCE QUERY [RANGE_MINUTES] [STEP_SECONDS]
```

### Generate Explore URL
```bash
./scripts/url.sh DATASOURCE QUERY [RANGE]
```

## PromQL Query Language

### Selectors

| Operator | Description |
|----------|-------------|
| `=` | Exact match |
| `!=` | Not equal |
| `=~` | Regex match |
| `!~` | Regex non-match |

Example: `http_requests_total{namespace="my-app", pod=~"web-.*"}`

### Functions

| Function | Description |
|----------|-------------|
| `rate(m[5m])` | Per-second rate over interval |
| `increase(m[1h])` | Total increase over interval |
| `sum(...)` | Sum across series |
| `avg(...)` | Average across series |
| `max(...)` / `min(...)` | Max/min across series |
| `count(...)` | Count series |
| `histogram_quantile(0.95, ...)` | Percentile from histogram |
| `topk(10, ...)` | Top K series by value |
| `bottomk(10, ...)` | Bottom K series by value |

### Aggregation

```promql
sum by (namespace, pod) (rate(metric[5m]))
avg without (instance) (metric)
```

## Common Metrics

### Container CPU
```bash
./scripts/query.sh <datasource> \
  'avg by (namespace, pod) (rate(container_cpu_usage_seconds_total{namespace="<namespace>", pod=~"<app>.*"}[$__rate_interval]))' \
  30 60
```

### Container Memory
```bash
./scripts/query.sh <datasource> \
  'avg by (namespace, pod) (container_memory_working_set_bytes{namespace="<namespace>", pod=~"<app>.*"})' \
  30 60
```

### HTTP Request Rate
```bash
./scripts/query.sh <datasource> \
  'sum by (status_code) (rate(http_requests_total{namespace="<namespace>"}[5m]))' \
  30 60
```

### HTTP Error Rate
```bash
./scripts/query.sh <datasource> \
  'sum(rate(http_requests_total{namespace="<namespace>", status_code=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="<namespace>"}[5m]))' \
  30 60
```

### HTTP Latency (Histogram)
```bash
./scripts/query.sh <datasource> \
  'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{namespace="<namespace>"}[5m])))' \
  30 60
```

### Pod Restarts
```bash
./scripts/query.sh <datasource> \
  'increase(kube_pod_container_status_restarts_total{namespace="<namespace>"}[1h])' \
  60 60
```

### Resource Limits and Requests
```bash
# CPU limits
./scripts/query.sh <datasource> 'kube_pod_container_resource_limits{resource="cpu", namespace="<namespace>"}' 5 60

# Memory limits
./scripts/query.sh <datasource> 'kube_pod_container_resource_limits{resource="memory", namespace="<namespace>"}' 5 60
```

## Workflow

1. **Fetch to temp file**:
   ```bash
   ./scripts/query.sh <datasource> 'QUERY' 30 60 > /tmp/metrics.json
   ```

2. **Analyze with jq**:
   ```bash
   # List all series labels
   jq '.results.A.frames[].schema.fields[1].labels' /tmp/metrics.json

   # Get latest value for each series
   jq '.results.A.frames[] | {labels: .schema.fields[1].labels, value: .data.values[1][-1]}' /tmp/metrics.json

   # Count number of series
   jq '.results.A.frames | length' /tmp/metrics.json
   ```

3. **Generate URL for humans**:
   ```bash
   ./scripts/url.sh <datasource> 'rate(container_cpu_usage_seconds_total{namespace="<namespace>"}[$__rate_interval])' 'now-30m'
   ```

## Response Structure

The API returns data in frames format:
- One frame per time series
- `schema.fields[0]` - Time field
- `schema.fields[1]` - Value field with labels
- `data.values[0]` - Timestamps (milliseconds)
- `data.values[1]` - Metric values

## URL Time Formats

- Relative: `now-5m`, `now-30m`, `now-1h`, `now-6h`, `now-1d`
- Absolute: `2024-01-24T12:00:00Z`

## Special Variables

Use these in queries for auto-scaling intervals:
- `$__rate_interval` - Recommended for `rate()` and `increase()`
- `$__interval` - Query resolution interval
