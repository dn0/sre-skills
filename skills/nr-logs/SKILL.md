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

Tooling (either works; the CLI is preferred when present):
- [`newrelic` CLI](https://github.com/newrelic/newrelic-cli) - reads the two env vars above automatically
- or `curl` + `jq` - used as the fallback transport

Both paths also need `python3` for result formatting.

## Scripts

### Query logs (NRQL)
```bash
./scripts/query.sh NRQL [TIMEOUT_SECONDS]
```

Runs the NRQL (via the `newrelic` CLI when installed, otherwise the NerdGraph API over curl+jq — same results either way), **copies the NRQL to the system clipboard** (macOS `pbcopy`, or `wl-copy` / `xclip` on Linux), prints **`Data exploration URL: https://one.newrelic.com/data-exploration?account=<numeric_account_id>`**, then prints **results**:

- **FACET aggregates** → **markdown table** (one column per facet dimension plus metric columns).
- **Other shapes** (raw rows, timeseries) → **indented JSON**.

Pass `--raw` as the first argument to get the **NRQL results array** as JSON (for `jq` pipelines or saving to a file). The array is the same list you would find under `data.actor.account.nrql.results` in a raw NerdGraph response — the script has already unwrapped it.

**Agents:** Copy the **Data exploration URL** line from script output verbatim—never replace the account id with placeholders like `${NEW_RELIC_ACCOUNT_ID}`.

### Generate Query Builder URL
```bash
./scripts/url.sh NRQL
```

Prints the Data exploration URL and the NRQL text (and copies the NRQL to the clipboard). Open that page, expand the bottom **Query your data** drawer, switch to NRQL, paste, and Run.

There is deliberately **no one-click deep link with the query embedded**. New Relic's "Copy query link" produces a shortened `onenr.io` URL that redirects to `.../unified-data-exploration/share?...&state=<UUID>`, where the query is stored server-side and referenced by an opaque UUID created by the UI — it cannot be constructed offline. For a shareable link, run the query once in the UI and click **Copy query link**. For a durable, greppable link you *can* generate programmatically, put the query on a **dashboard** (dashboards expose a stable `permalinkUrl` via NerdGraph).

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

**Field names depend on how logs are shipped — do not assume these exist. [Discover the real fields](#discovering-log-fields) first.** In particular, clusters that forward logs via the **OpenTelemetry collector** use dotted `k8s.*` names (which must be **backticked** in NRQL), while older Fluent Bit / infra-agent pipelines use the flat names below.

| Purpose | Fluent Bit / infra agent | OpenTelemetry collector |
|---------|--------------------------|-------------------------|
| Namespace | `namespace` | `` `k8s.namespace.name` `` |
| Pod name | `pod_name` / `pod` | `` `k8s.pod.name` `` |
| Container | `container_name` | `` `k8s.container.name` `` |
| Deployment | (often absent) | `` `k8s.deployment.name` `` |
| Cluster | `cluster_name` | `` `k8s.cluster.name` `` |
| App label | `labels.app` | `labels.app` (if labelled) |

Content/severity fields that are **not guaranteed** — many pipelines emit structured logs with no `message` or `level` at all (see discovery):

| Field | Description |
|-------|-------------|
| `message` | Log message body (may be absent for structured/JSON logs) |
| `level` / `severity` | Log level (ERROR, WARN, INFO, DEBUG) — absent in many pipelines |
| `hostname` | Host name |
| `error.class` / `error.message` / `error.code` | Error details (app-dependent) |

## Discovering Log Fields

Logs from different shippers carry **different attributes**, and structured (JSON) logs often have **no `message` or `level`** — the content lives in typed fields (`request.path`, `response.status_code`, …). When you don't know the schema, discover it before querying.

```bash
# What attributes does a log record actually have? Read a sample row's keys.
# (--raw is the results array, so index [0] and read its keys.)
./scripts/query.sh --raw "FROM Log SELECT * WHERE <some narrowing filter> SINCE 30 minutes ago LIMIT 1" \
  | jq '.[0] | keys'

# See attributes with sample values (skip noisy metadata):
./scripts/query.sh --raw "FROM Log SELECT * WHERE <filter> SINCE 30 minutes ago LIMIT 1" \
  | jq -r '.[0] | to_entries[] | "\(.key) = \(.value|tostring|.[0:120])"'

# Which k8s label is the cluster/namespace/deployment? Find valid values:
./scripts/query.sh "FROM Log SELECT count(*) FACET \`k8s.deployment.name\` SINCE 1 hour ago LIMIT 50"

# Is there a message/level at all? Measure coverage before relying on them:
./scripts/query.sh "FROM Log SELECT count(*) AS total, filter(count(*), WHERE message IS NOT NULL) AS has_message, filter(count(*), WHERE level IS NOT NULL) AS has_level WHERE <filter> SINCE 1 hour ago"
```

**Gotchas**
- **Backtick dotted field names.** OTel attributes like `` `k8s.pod.name` `` contain dots and must be backticked in `WHERE`, `SELECT`, and `FACET`.
- **Don't assume `message`/`level` exist.** If a `WHERE level = 'ERROR'` filter returns nothing, check coverage (above) — the pipeline may not set those. For structured logs, filter on the real fields (e.g. `` `response.status_code` >= 500 ``) instead.
- **Pick fields for readable output.** `SELECT *` on structured logs is noisy; select the few attributes that matter (timestamp, pod, and the payload fields you discovered).

## Common Queries

> The examples below use the flat field names (`namespace`, `pod_name`, …). On OpenTelemetry clusters substitute the backticked `k8s.*` equivalents (e.g. `` `k8s.namespace.name` ``) — see [Discovering Log Fields](#discovering-log-fields).

### Kubernetes Deployment Logs (OTel field names)
```bash
./scripts/query.sh --raw "FROM Log SELECT timestamp, \`k8s.pod.name\`, \`request.method\`, \`response.status_code\`, \`request.path\` WHERE \`k8s.cluster.name\` = '<cluster>' AND \`k8s.namespace.name\` = '<namespace>' AND \`k8s.deployment.name\` = '<deployment>' SINCE 30 MINUTES AGO LIMIT 100" \
  | jq -r '. | sort_by(.timestamp) | reverse | .[] | [(.timestamp/1000|strftime("%H:%M:%S")), .["k8s.pod.name"], (.["response.status_code"]|tostring), .["request.path"]] | @tsv'
```

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

1. **Fetch to temp file** (`--raw` emits the results array):
   ```bash
   ./scripts/query.sh --raw "FROM Log SELECT * WHERE labels.app = '<app-name>' AND level = 'ERROR' SINCE 1 HOUR AGO LIMIT 500" > /tmp/nr-logs.json
   ```

2. **Analyze with jq** (the file is already the results array):
   ```bash
   # View results
   jq '.' /tmp/nr-logs.json

   # Count results
   jq 'length' /tmp/nr-logs.json

   # Extract messages
   jq -r '.[].message' /tmp/nr-logs.json

   # Group by a field
   jq -r '[.[].level] | group_by(.) | map({level: .[0], count: length})' /tmp/nr-logs.json
   ```

3. **Share with a human**: run `./scripts/url.sh` with the same NRQL — it prints the console URL and the NRQL to paste. For a shareable link, the human runs it once in the UI and clicks **Copy query link** (server-backed; not constructable offline).

## Response Structure

`--raw` returns the **results array** directly (the script unwraps NerdGraph's `data.actor.account.nrql.results` for you, and the `newrelic` CLI returns the same array natively):
```json
[
  { "message": "...", "level": "ERROR", "timestamp": 1706097600000 }
]
```

For aggregation queries, each element holds the computed values:
```json
[
  { "count": 1234, "facet": "ERROR" },
  { "count": 5678, "facet": "WARN" }
]
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
