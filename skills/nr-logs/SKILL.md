---
name: nr-logs
description: Query and analyze New Relic logs via NRQL. Use when investigating application logs, Kubernetes pod/container logs, error patterns, or log volume in New Relic. Generates Data exploration URLs for humans.
---

# New Relic Logs Skill

Query and analyze logs from New Relic via NRQL and the NerdGraph API.

## Requirements

Environment variables:
- `NEW_RELIC_API_KEY` - User API key (NRAK prefix)
- `NEW_RELIC_ACCOUNT_ID` - Numeric account ID

## Scripts

### Query logs (NRQL)
```bash
./scripts/query.sh NRQL [TIMEOUT_SECONDS]
```

Runs the NRQL via NerdGraph, **copies the NRQL to the system clipboard** (macOS `pbcopy`, or `wl-copy` / `xclip` on Linux), prints **`Data exploration URL: https://one.newrelic.com/data-exploration?account=<numeric_account_id>`**, then prints **results**:

- **FACET aggregates** → **markdown table** (one column per facet dimension plus metric columns).
- **Other shapes** (raw rows, timeseries) → **indented JSON**.

Pass `--raw` as the first argument to get the full NerdGraph JSON (for `jq` pipelines or saving to a file).

**Agents:** Copy the **Data exploration URL** line from script output verbatim—never replace the account id with placeholders like `${NEW_RELIC_ACCOUNT_ID}`.

### Generate Query Builder URL
```bash
./scripts/url.sh NRQL
```

Prints the Data exploration URL and NRQL text. Open that page, expand the bottom **Query your data** drawer, switch to NRQL, paste, and Run. After running once, use **Copy query link** in the console for a shareable URL.

## NRQL for Logs

All log queries use the `Log` event type. Time ranges are part of the NRQL query itself (`SINCE`, `UNTIL`).

### Basic Syntax

```sql
FROM Log SELECT <fields|aggregation>
WHERE <conditions>
[FACET <field>]
[SINCE <time> [UNTIL <time>]]
[LIMIT <max>]
```

### Operators

| Operator | Description |
|----------|-------------|
| `=` | Exact match |
| `!=` | Not equal |
| `LIKE` | Wildcard match (`%` = any chars) |
| `NOT LIKE` | Wildcard non-match |
| `RLIKE` | Regex match |
| `IN (...)` | Match any in list |
| `IS NULL` / `IS NOT NULL` | Null check |

Boolean: `AND`, `OR`, `NOT`

### Aggregation Functions

| Function | Description |
|----------|-------------|
| `count(*)` | Count log entries |
| `rate(count(*), 1 minute)` | Per-minute rate |
| `uniqueCount(field)` | Distinct values |
| `latest(field)` | Most recent value |
| `max(timestamp)` | Latest timestamp |

### Common Log Fields

| Field | Description |
|-------|-------------|
| `message` | Log message body |
| `level` / `severity` | Log level (ERROR, WARN, INFO, DEBUG) |
| `labels.app` | Application name (K8s label) |
| `namespace` | Kubernetes namespace |
| `pod_name` / `pod` | Kubernetes pod name |
| `container_name` | Container name |
| `cluster_name` | Cluster name |
| `hostname` | Host name |
| `error.class` | Error class/type |
| `error.message` | Error message |
| `error.code` | Error code (ETIMEDOUT, ECONNRESET, etc.) |

## Common Queries

### Application Error Logs
```bash
./scripts/query.sh "FROM Log SELECT * WHERE labels.app = '<app-name>' AND level = 'ERROR' SINCE 30 MINUTES AGO LIMIT 100"
```

### Log Volume by Level
```bash
./scripts/query.sh "FROM Log SELECT count(*) FROM Log WHERE labels.app = '<app-name>' FACET level SINCE 1 HOUR AGO"
```

### Error Rate Over Time
```bash
./scripts/query.sh "FROM Log SELECT rate(count(*), 1 minute) WHERE level = 'ERROR' FACET labels.app SINCE 1 HOUR AGO TIMESERIES"
```

### Search by Message Content
```bash
./scripts/query.sh "FROM Log SELECT * WHERE message LIKE '%Exception%' AND namespace = '<namespace>' SINCE 30 MINUTES AGO LIMIT 100"
```

### Client Timeout Errors
```bash
./scripts/query.sh "FROM Log SELECT rate(count(*), 1 minute) WHERE labels.app = '<app-name>' AND error.code IN ('ETIMEDOUT', 'ECONNABORTED', 'ECONNRESET') FACET error.code SINCE 1 HOUR AGO TIMESERIES"
```

### Kubernetes Namespace Logs
```bash
./scripts/query.sh "FROM Log SELECT * WHERE namespace = '<namespace>' AND level != 'INFO' SINCE 15 MINUTES AGO LIMIT 200"
```

### Kube-system Errors
```bash
./scripts/query.sh "FROM Log SELECT * WHERE namespace = 'kube-system' AND level = 'error' SINCE 1 HOUR AGO LIMIT 100"
```

### Log Count by Pod
```bash
./scripts/query.sh "FROM Log SELECT count(*) WHERE namespace = '<namespace>' FACET pod_name SINCE 30 MINUTES AGO"
```

## Workflow

1. **Fetch to temp file** (use `--raw` for full JSON):
   ```bash
   ./scripts/query.sh --raw "FROM Log SELECT * WHERE labels.app = '<app-name>' AND level = 'ERROR' SINCE 1 HOUR AGO LIMIT 500" > /tmp/nr-logs.json
   ```

2. **Analyze with jq**:
   ```bash
   # Extract results array
   jq '.data.actor.account.nrql.results' /tmp/nr-logs.json

   # Count results
   jq '.data.actor.account.nrql.results | length' /tmp/nr-logs.json

   # Extract messages
   jq -r '.data.actor.account.nrql.results[].message' /tmp/nr-logs.json

   # Group by a field
   jq -r '[.data.actor.account.nrql.results[].level] | group_by(.) | map({level: .[0], count: length})' /tmp/nr-logs.json
   ```

3. **Generate URL**: run `./scripts/url.sh` with the same NRQL. After running once in the UI, **Copy query link** shares a URL that embeds the query.

## Response Structure

NerdGraph returns NRQL results in this structure:
```json
{
  "data": {
    "actor": {
      "account": {
        "nrql": {
          "results": [
            { "message": "...", "level": "ERROR", "timestamp": 1706097600000, ... }
          ]
        }
      }
    }
  }
}
```

For aggregation queries, results contain the computed values:
```json
{
  "results": [
    { "count": 1234, "facet": "ERROR" },
    { "count": 5678, "facet": "WARN" }
  ]
}
```

## Time Formats in NRQL

- Relative: `SINCE 30 MINUTES AGO`, `SINCE 1 HOUR AGO`, `SINCE 6 HOURS AGO`, `SINCE 1 DAY AGO`
- Absolute: `SINCE '2024-01-24 12:00:00' UNTIL '2024-01-24 13:00:00'`
- With TIMESERIES: add `TIMESERIES` for time-bucketed results, optionally `TIMESERIES 1 MINUTE`

## Best Practices

1. **Use indexed fields in WHERE** - `labels.app`, `namespace`, `level` are indexed and fast
2. **Narrow time range** - Shorter ranges = faster queries
3. **Use LIMIT** - Default is 10 for `SELECT *`; set explicitly for more results (max 2000)
4. **FACET for grouping** - More efficient than fetching raw logs and counting client-side
5. **TIMESERIES for trends** - Shows values over time buckets instead of a single aggregate
