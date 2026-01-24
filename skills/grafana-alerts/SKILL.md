---
name: grafana-alerts
description: Query firing alerts from Grafana Alertmanager. Use when checking alert status, investigating firing alerts, reviewing silenced alerts, or verifying configured alert rules. Supports both Grafana-managed and external (Prometheus) alerting rules.
---

# Grafana Alerts Skill

Query alerts from Alertmanager or Prometheus via Grafana API.

## Requirements

Environment variables:
- `GRAFANA_URL` - Grafana instance URL
- `GRAFANA_API_KEY` - Service account token

## First Step: Find Alert Data Sources

There are two types of alert sources:
1. **Alertmanager** - Shows alerts sent to Alertmanager (may be silenced/inhibited)
2. **Prometheus/Mimir** - Shows alerts directly from alerting rules ("Data source-managed")

List available data sources:
```bash
./scripts/list-datasources.sh
```

To see ALL firing alerts, query each Prometheus/Mimir datasource.

## Scripts

### List alert data sources
```bash
./scripts/list-datasources.sh
```

### Query alerts
```bash
./scripts/query.sh DATASOURCE [STATE] [TYPE]
```

- **DATASOURCE**: The datasource UID
- **STATE**:
  - Alertmanager: `all` (default), `active`, `silenced`
  - Prometheus: `alerts` (default), `rules` (all configured rules)
- **TYPE**: `auto` (default), `alertmanager`, `prometheus`

The script auto-detects the datasource type.

## Common Queries

### Get firing alerts from Prometheus datasource
```bash
./scripts/query.sh prometheus-prod | jq '[.data.alerts[] | select(.state == "firing")]'
```

### Get all alerts from Alertmanager (including silenced)
```bash
./scripts/query.sh alertmanager-prod
```

### Get active alerts from Alertmanager (not silenced)
```bash
./scripts/query.sh alertmanager-prod active
```

### Get all configured rules (alerting and recording)
```bash
./scripts/query.sh prometheus-prod rules
```

### List all alerting rule names
```bash
./scripts/query.sh prometheus-prod rules | jq -r '.data.groups[].rules[] | select(.type == "alerting") | .name'
```

### Find rules with errors or no data
```bash
./scripts/query.sh prometheus-prod rules | jq '[.data.groups[].rules[] | select(.health == "error" or .health == "nodata")]'
```

### Check if a specific alert rule exists
```bash
./scripts/query.sh prometheus-prod rules | jq '.data.groups[].rules[] | select(.name == "MyAlertName")'
```

## Workflow

1. **List all data sources with alerts**:
   ```bash
   ./scripts/list-datasources.sh
   ```

2. **Query each Prometheus datasource for firing alerts**:
   ```bash
   # Query each datasource
   ./scripts/query.sh prometheus-main > /tmp/alerts-main.json
   ./scripts/query.sh prometheus-mgmt > /tmp/alerts-mgmt.json

   # Count firing alerts
   jq '[.data.alerts[] | select(.state == "firing")] | length' /tmp/alerts-main.json
   ```

3. **Analyze with jq**:
   ```bash
   # List firing alert names
   jq -r '.data.alerts[] | select(.state == "firing") | .labels.alertname' /tmp/alerts-main.json

   # Filter by severity
   jq '[.data.alerts[] | select(.state == "firing" and .labels.severity == "critical")]' /tmp/alerts-main.json

   # Get alert summaries
   jq -r '.data.alerts[] | select(.state == "firing") | "\(.labels.alertname): \(.annotations.summary)"' /tmp/alerts-main.json
   ```

4. **Provide URL for humans** (see URLs section below)

## URLs for Humans

- **All alerts**: `${GRAFANA_URL}/alerting/list`
- **Firing only**: `${GRAFANA_URL}/alerting/list?search=state:firing`

## Response Structure

### Prometheus Alerts Response
```json
{
  "status": "success",
  "data": {
    "alerts": [{
      "labels": {"alertname": "...", "severity": "..."},
      "annotations": {"summary": "...", "description": "..."},
      "state": "firing|pending|inactive",
      "activeAt": "2024-01-24T12:00:00Z",
      "value": "1e+00"
    }]
  }
}
```

### Prometheus Rules Response
```json
{
  "status": "success",
  "data": {
    "groups": [{
      "name": "GroupName",
      "file": "/path/to/rules.yaml",
      "rules": [{
        "name": "AlertName",
        "query": "promql_expression",
        "duration": 60,
        "labels": {"severity": "warning"},
        "annotations": {"summary": "...", "description": "..."},
        "state": "inactive|pending|firing",
        "health": "ok|error|nodata",
        "type": "alerting|recording",
        "lastEvaluation": "2024-01-24T12:00:00Z",
        "evaluationTime": 0.001
      }]
    }]
  }
}
```

### Alertmanager API Response
```json
[{
  "labels": {"alertname": "...", "severity": "..."},
  "annotations": {"summary": "...", "description": "..."},
  "status": {"state": "active|suppressed"},
  "startsAt": "...",
  "endsAt": "...",
  "fingerprint": "..."
}]
```

## Common Labels

| Label | Description |
|-------|-------------|
| `alertname` | Name of the alert rule |
| `severity` | critical, warning, info |
| `namespace` | Kubernetes namespace |
| `pod` | Pod name |
| `cluster` | Cluster name |
| `team` | Responsible team |
