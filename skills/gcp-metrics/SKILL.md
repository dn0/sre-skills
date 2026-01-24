---
name: gcp-metrics
description: Query Google Cloud Monitoring metrics using PromQL. Use when analyzing GCP metrics, GKE container/node CPU/memory, GCE instance utilization, load balancer request rates, or any Cloud Monitoring time series data. Generates Metrics Explorer URLs for humans.
---

# GCP Metrics Skill

Query Google Cloud Monitoring metrics using PromQL via the Prometheus-compatible API.

## Scripts

### Range query (time series)
```bash
./scripts/query.sh PROJECT QUERY [START_OFFSET_SECONDS] [END_OFFSET_SECONDS] [STEP_SECONDS]
```

### Instant query (single point)
```bash
./scripts/query-instant.sh PROJECT QUERY
```

### Generate Metrics Explorer URL
```bash
./scripts/url.sh PROJECT QUERY [DURATION]
```

## PromQL Syntax for GCP Metrics

GCP metrics use UTF-8 names. Query format:
```promql
{"__name__"="metric.path/name", "label"="value"}
```

## Common Metrics

### GKE Container
| Metric | Type |
|--------|------|
| `kubernetes.io/container/cpu/core_usage_time` | Counter |
| `kubernetes.io/container/cpu/limit_utilization` | Gauge |
| `kubernetes.io/container/memory/used_bytes` | Gauge |
| `kubernetes.io/container/memory/limit_utilization` | Gauge |
| `kubernetes.io/container/restart_count` | Counter |

Labels: `pod_name`, `container_name`, `namespace_name`, `cluster_name`

### GKE Node
| Metric | Type |
|--------|------|
| `kubernetes.io/node/cpu/core_usage_time` | Counter |
| `kubernetes.io/node/cpu/allocatable_cores` | Gauge |
| `kubernetes.io/node/memory/used_bytes` | Gauge |

### GCE Instance
| Metric | Type |
|--------|------|
| `compute.googleapis.com/instance/cpu/utilization` | Gauge |
| `compute.googleapis.com/instance/disk/read_bytes_count` | Counter |
| `compute.googleapis.com/instance/network/received_bytes_count` | Counter |

Labels: `instance_name`, `instance_id`, `zone`

### Load Balancer
| Metric | Type |
|--------|------|
| `loadbalancing.googleapis.com/https/request_count` | Counter |
| `loadbalancing.googleapis.com/https/total_latencies` | Distribution |
| `loadbalancing.googleapis.com/https/backend_latencies` | Distribution |

Labels: `response_code`, `response_code_class`, `backend_target_name`, `client_country`

## Example Queries

### Container CPU rate by pod
```bash
./scripts/query.sh <project-id> \
  'avg by (pod_name)(rate({"__name__"="kubernetes.io/container/cpu/core_usage_time","monitored_resource"="k8s_container","pod_name"=~"my-app.*"}[5m]))' \
  3600 0 60
```

### GCE CPU utilization
```bash
./scripts/query-instant.sh <project-id> \
  '{"__name__"="compute.googleapis.com/instance/cpu/utilization","monitored_resource"="gce_instance"}'
```

### Load balancer request rate by status
```bash
./scripts/query.sh <project-id> \
  'sum by (response_code_class)(rate({"__name__"="loadbalancing.googleapis.com/https/request_count","monitored_resource"="https_lb_rule"}[5m]))' \
  1800 0 60
```

## Workflow

1. **Fetch to temp file**:
   ```bash
   ./scripts/query.sh <project-id> 'QUERY' 3600 0 60 > /tmp/metrics.json
   ```

2. **Analyze with jq**:
   ```bash
   # List series
   jq '.data.result[].metric' /tmp/metrics.json

   # Latest values
   jq '.data.result[] | {label: .metric.pod_name, value: .values[-1][1]}' /tmp/metrics.json

   # Max value
   jq '[.data.result[].values[][1] | tonumber] | max' /tmp/metrics.json
   ```

3. **Generate URL for humans**:
   ```bash
   ./scripts/url.sh <project-id> 'rate({"__name__"="kubernetes.io/container/cpu/core_usage_time","pod_name"=~"my-app.*"}[5m])' PT30M
   ```

## URL Time Formats

- Relative: `PT30M`, `PT1H`, `PT6H`
- Absolute: Use `startTime` and `endTime` in URL path
