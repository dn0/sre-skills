---
name: grafana-loki
description: Query and analyze logs from Grafana Loki. Use when investigating application logs, Kubernetes pod/container logs, ingress access logs, or kube-events via Grafana. Generates Grafana Explore URLs for humans.
---

# Grafana Loki Skill

Query and analyze logs from Loki via Grafana API.

## Requirements

Environment variables:
- `GRAFANA_URL` - Grafana instance URL
- `GRAFANA_API_KEY` - Service account token

## First Step: Find the Data Source

All queries require a Loki data source name/UID. List available Loki data sources:
```bash
./scripts/list-datasources.sh
```

If the user hasn't provided a data source name, run this script first and ask them to specify which one to use.

## Scripts

### List Loki data sources
```bash
./scripts/list-datasources.sh
```

### Query logs
```bash
./scripts/query.sh DATASOURCE QUERY [RANGE_MINUTES] [LIMIT]
```

### Generate Explore URL
```bash
./scripts/url.sh DATASOURCE QUERY [RANGE]
```

## LogQL Query Language

### Stream Selectors (Labels)

Labels are indexed - always filter by labels first for performance.

| Operator | Description |
|----------|-------------|
| `=` | Exact match |
| `!=` | Not equal |
| `=~` | Regex match |
| `!~` | Regex non-match |

Common labels: `namespace`, `app`, `pod`, `container`, `job`, `cluster`

### Line Filters

| Operator | Description |
|----------|-------------|
| `\|=` | Line contains string |
| `!=` | Line does not contain |
| `\|~` | Line matches regex |
| `!~` | Line does not match regex |

### Parsers

| Parser | Usage |
|--------|-------|
| `\| json` | Parse JSON logs, extracts all fields |
| `\| logfmt` | Parse key=value format |
| `\| pattern "<pattern>"` | Extract with named captures |
| `\| regexp "(?P<name>re)"` | Extract with regex groups |

### Label Filters (after parsing)

```logql
| json | level != "info"
| json | status >= 400
| json | duration > 1s
```

## Common Queries

### Application Logs
```bash
./scripts/query.sh <datasource> '{namespace="<namespace>", app="<app-name>"} | json' 30 100
```

Filter by level:
```bash
./scripts/query.sh <datasource> '{namespace="<namespace>", app="<app-name>"} | json | level != "info"' 30 100
```

### Pod Logs
```bash
./scripts/query.sh <datasource> '{namespace="<namespace>", pod=~"<app-name>.*"} | json' 30 100
```

### Ingress Access Logs
```bash
./scripts/query.sh <datasource> '{namespace="ingress-nginx"} | json' 15 100
```

Filter by status code:
```bash
./scripts/query.sh <datasource> '{namespace="ingress-nginx"} | json | status =~ "[45].*"' 15 100
```

### Kubernetes Events
```bash
./scripts/query.sh <datasource> '{job="kube-events"} | json' 60 50
```

Warning events only:
```bash
./scripts/query.sh <datasource> '{job="kube-events", type="Warning"} | json' 60 50
```

OOMKilled events:
```bash
./scripts/query.sh <datasource> '{job="kube-events", reason="OOMKilling"}' 60 50
```

### Search for Errors
```bash
./scripts/query.sh <datasource> '{namespace="<namespace>"} |~ "(ERROR|error|Error|Exception)"' 30 100
```

## Workflow

1. **Fetch to temp file**:
   ```bash
   ./scripts/query.sh <datasource> '{namespace="<namespace>"}' 30 100 > /tmp/logs.json
   ```

2. **Analyze with jq**:
   ```bash
   # Extract log lines
   jq -r '.results.A.frames[0].data.values[2][]' /tmp/logs.json

   # Count by label (e.g., pod)
   jq -r '.results.A.frames[0].data.values[0][].pod' /tmp/logs.json | sort | uniq -c | sort -rn

   # Parse JSON log lines and filter
   jq -r '.results.A.frames[0].data.values[2][]' /tmp/logs.json | jq -s '[.[] | fromjson | select(.level == "error")]'
   ```

3. **Generate URL for humans**:
   ```bash
   ./scripts/url.sh <datasource> '{namespace="<namespace>", app="<app-name>"} | json' 'now-30m'
   ```

## Response Structure

The API returns data in frames format:
- `values[0]` - Labels (JSON objects)
- `values[1]` - Timestamps (milliseconds)
- `values[2]` - Log lines (strings)

## URL Time Formats

- Relative: `now-5m`, `now-30m`, `now-1h`, `now-6h`, `now-1d`
- Absolute: `2024-01-24T12:00:00Z`

## Best Practices

1. **Use labels first** - Labels are indexed, line filters are not
2. **Narrow time range** - Shorter ranges = faster queries
3. **Filter before parsing** - Use `|= "search"` before `| json`
4. **Prefer string match over regex** - `|= "error"` is faster than `|~ "error"`
