---
name: gcp-logs
description: Query and analyze Google Cloud Logging logs. Use when investigating GCP logs, HTTP load balancer requests, GKE container/pod logs, GCE instance logs, or Kubernetes events. Generates Logs Explorer URLs for humans.
---

# GCP Logs Skill

Fetch and analyze logs from Google Cloud Logging.

## Scripts

### Query logs (CSV output)
```bash
./scripts/query.sh PROJECT FILTER FORMAT_FIELDS [LIMIT] [FRESHNESS]
```

### Query logs (JSON output - for exploration)
```bash
./scripts/query-json.sh PROJECT FILTER [LIMIT] [FRESHNESS]
```

### Generate Logs Explorer URL
```bash
./scripts/url.sh PROJECT QUERY [DURATION]
```

## Query Language

| Operator | Description |
|----------|-------------|
| `=`, `!=` | Exact match |
| `>`, `<`, `>=`, `<=` | Numeric/timestamp comparison |
| `:` | Substring/has match |
| `=~`, `!~` | Regex match (RE2 syntax) |

Boolean: `AND`, `OR`, `NOT` (uppercase), `-` for negation.

## Common Resource Types

### HTTP Load Balancer
```bash
./scripts/query.sh <project-id> 'resource.type="http_load_balancer"' \
  'timestamp,severity,httpRequest.status,httpRequest.requestMethod,httpRequest.requestUrl,httpRequest.latency,jsonPayload.statusDetails' 1000
```

Filters: `httpRequest.status>=500`, `httpRequest.requestUrl:"/api/"`, `jsonPayload.statusDetails!="response_sent_by_backend"`

### GKE Container Logs
```bash
./scripts/query.sh <project-id> 'resource.type="k8s_container"' \
  'timestamp,severity,resource.labels.namespace_name,resource.labels.pod_name,resource.labels.container_name,textPayload' 1000
```

Filters: `resource.labels.pod_name:"my-app-"`, `severity>="ERROR"`, `textPayload:"Exception"`

### GKE Events
```bash
./scripts/query.sh <project-id> 'LOG_ID("events")' \
  'timestamp,severity,resource.labels.cluster_name,jsonPayload.involvedObject.kind,jsonPayload.involvedObject.name,jsonPayload.reason' 500
```

### GCE Instance Logs
```bash
./scripts/query.sh <project-id> 'resource.type="gce_instance"' \
  'timestamp,severity,resource.labels.instance_id,logName,textPayload' 1000
```

## Workflow

1. **Fetch to temp file**:
   ```bash
   ./scripts/query.sh <project-id> 'FILTER' 'FIELDS' LIMIT > /tmp/logs.csv
   ```

2. **Analyze with awk**:
   ```bash
   # Count by field (e.g., status code in column 3)
   awk -F',' 'NR>1 {count[$3]++} END {for (k in count) print k, count[k]}' /tmp/logs.csv

   # Count by minute
   awk -F',' 'NR>1 {min=substr($1,1,16); count[min]++} END {for (m in count) print m, count[m]}' /tmp/logs.csv | sort
   ```

3. **Generate URL for humans**:
   ```bash
   ./scripts/url.sh <project-id> 'resource.type="http_load_balancer" AND httpRequest.status>=500' PT30M
   ```

## URL Time Formats

- Relative: `PT30M` (30 min), `PT1H` (1 hour), `PT6H` (6 hours)
- Absolute: Use `startTime` and `endTime` parameters in the URL
