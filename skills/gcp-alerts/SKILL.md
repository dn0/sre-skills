---
name: gcp-alerts
description: Query GCP Cloud Monitoring alert policies and incidents. Use when checking alert status, listing configured alerts, investigating recent incidents, or reviewing alert configurations. Generates Alerting console URLs for humans.
---

# GCP Alerts Skill

Query alert policies and incidents from Google Cloud Monitoring.

## Prerequisites

**GCP Project ID is required.** If the user has not provided a GCP project ID, ask them for it before proceeding. All scripts require the project ID as the first argument.

**gcloud beta components required.** Install with: `gcloud components install beta`

## Scripts

### List alert policies
```bash
./scripts/list-policies.sh PROJECT [enabled|all]
```

### Query alerts/incidents
```bash
./scripts/query.sh PROJECT [STATE] [LIMIT]
```
- **STATE**: `open`, `closed`, `all` (default: `all`)

### Generate Alerting console URL
```bash
./scripts/url.sh PROJECT [TYPE] [ID]
```
- **TYPE**: `overview` (default), `alert`, `policy`

## Common Queries

### Get open/firing alerts
```bash
./scripts/query.sh <project-id> open
```

### Get open alerts with links
```bash
./scripts/query.sh <project-id> open | jq -r '.[] | "Alert: \(.policy.displayName)\nSeverity: \(.policy.severity)\nOpen since: \(.openTime)\nURL: https://console.cloud.google.com/monitoring/alerting/alerts/\(.name | split("/") | last)?project=<project-id>\n"'
```

### Get recent closed alerts
```bash
./scripts/query.sh <project-id> closed 20
```

### List all enabled alert policies
```bash
./scripts/list-policies.sh <project-id> enabled
```

### Find alerts for a specific policy
```bash
./scripts/query.sh <project-id> all 100 | jq '[.[] | select(.policy.displayName | contains("Uptime"))]'
```

### List policies by severity
```bash
./scripts/list-policies.sh <project-id> enabled | jq '[.[] | select(.severity == "CRITICAL")]'
```

## Workflow

1. **Check for open alerts**:
   ```bash
   ./scripts/query.sh <project-id> open > /tmp/open-alerts.json
   ```

2. **Analyze with jq**:
   ```bash
   # Count open alerts
   jq 'length' /tmp/open-alerts.json

   # List open alert names
   jq -r '.[].policy.displayName' /tmp/open-alerts.json

   # Get alert IDs for URLs
   jq -r '.[] | .name | split("/") | last' /tmp/open-alerts.json
   ```

3. **Generate URLs for humans**:
   ```bash
   # Alerting overview
   ./scripts/url.sh <project-id>

   # Specific alert/incident
   ./scripts/url.sh <project-id> alert 0.nsxvqhqxb9ym

   # Specific policy configuration
   ./scripts/url.sh <project-id> policy 17435544969820093568
   ```

## URLs for Humans

### Alerting overview
```
https://console.cloud.google.com/monitoring/alerting?project=<project-id>
```

### Specific alert/incident
```
https://console.cloud.google.com/monitoring/alerting/alerts/<alert-id>?project=<project-id>
```
The alert ID is from the alert name (e.g., `0.nsxvqhqxb9ym` from `projects/my-project/alerts/0.nsxvqhqxb9ym`).

### Specific alert policy (configuration)
```
https://console.cloud.google.com/monitoring/alerting/policies/<policy-id>?project=<project-id>
```
The policy ID is from the policy name (e.g., `17435544969820093568` from `projects/my-project/alertPolicies/17435544969820093568`).

## Response Structures

### Alert Policy (from list-policies.sh)
```json
{
  "name": "projects/<project>/alertPolicies/<id>",
  "displayName": "My Alert Policy",
  "enabled": true,
  "severity": "CRITICAL",
  "conditions": [...],
  "notificationChannels": [...]
}
```

### Alert/Incident (from query.sh)
```json
{
  "name": "projects/<project>/alerts/<alert-id>",
  "state": "OPEN",
  "openTime": "2024-01-24T10:00:00Z",
  "policy": {
    "name": "projects/<project>/alertPolicies/<policy-id>",
    "displayName": "My Alert Policy",
    "severity": "ERROR"
  },
  "resource": {
    "type": "prometheus_target",
    "labels": {...}
  },
  "metric": {
    "type": "...",
    "labels": {...}
  }
}
```

## Alert States

| State | Description |
|-------|-------------|
| `OPEN` | Alert is currently firing |
| `CLOSED` | Alert has been resolved |

## Severity Levels

| Severity | Description |
|----------|-------------|
| `CRITICAL` | Immediate attention required |
| `ERROR` | Significant issue |
| `WARNING` | Potential problem |
| (none) | Not specified |
