---
name: nr-metrics
description: Query New Relic metrics and APM data via NRQL. Use when analyzing application performance, Kubernetes container/pod metrics, AWS infrastructure metrics, error rates, latency, or synthetics results. Generates Data exploration URLs for humans.
---

# New Relic Metrics Skill

Query metrics, APM, and infrastructure data from New Relic via NRQL and the NerdGraph API.

## Requirements

Environment variables:
- `NEW_RELIC_API_KEY` - User API key (NRAK prefix)
- `NEW_RELIC_ACCOUNT_ID` - Numeric account ID

## Scripts

### Query metrics (NRQL)
```bash
./scripts/query.sh NRQL [TIMEOUT_SECONDS]
```

Runs the NRQL via NerdGraph, **copies the NRQL to the system clipboard** (macOS `pbcopy`, or `wl-copy` / `xclip` on Linux), prints **`Data exploration URL: https://one.newrelic.com/data-exploration?account=<numeric_account_id>`**, then prints **results**:

- **FACET aggregates** → **markdown table** (one column per facet dimension plus metric columns).
- **Other shapes** (timeseries, raw rows) → **indented JSON**.

Pass `--raw` as the first argument to get the full NerdGraph JSON (for `jq` pipelines or saving to a file).

**Agents:** Copy the **Data exploration URL** line from script output verbatim—never replace the account id with placeholders like `${NEW_RELIC_ACCOUNT_ID}`.

### Generate Query Builder URL
```bash
./scripts/url.sh NRQL
```

Prints the Data exploration URL and NRQL text. Open that page, expand the bottom **Query your data** drawer, switch to NRQL, paste, and Run. After running once, use **Copy query link** in the console for a shareable URL.

## NRQL for Metrics

Metrics come from multiple event types depending on the source. Time ranges are part of the NRQL query (`SINCE`, `UNTIL`).

### Basic Syntax

```sql
SELECT <aggregation> FROM <EventType>
WHERE <conditions>
[FACET <field>]
[SINCE <time> [UNTIL <time>]]
[TIMESERIES [bucket]]
```

### Aggregation Functions

| Function | Description |
|----------|-------------|
| `average(field)` | Mean value |
| `sum(field)` | Total |
| `max(field)` / `min(field)` | Extremes |
| `count(*)` | Event count |
| `rate(count(*), 1 minute)` | Per-minute rate |
| `percentage(count(*), WHERE cond)` | Percentage matching condition |
| `percentile(field, 50, 95, 99)` | Percentiles |
| `uniqueCount(field)` | Distinct values |
| `latest(field)` | Most recent value |
| `derivative(field)` | Rate of change |
| `filter(count(*), WHERE cond)` | Filtered aggregate (use in complex ratios) |
| `capture(field, r'regex')` | Extract named groups from strings (FACET) |

## Event Types

Fields marked **custom** are application-specific attributes. Adapt or remove these for your own services. Fields marked **K8s integration** are auto-added by the NR Kubernetes integration. Unmarked fields are standard NR APM agent attributes ([data dictionary](https://docs.newrelic.com/attribute-dictionary/?event=Transaction)).

### APM - Transaction
Application performance data from instrumented services.

| Field | Description |
|-------|-------------|
| `appName` | Application name |
| `duration` | Response time (seconds) |
| `error` | Boolean error flag (`WHERE error`, `percentage(…, WHERE error)`) |
| `http.statusCode` | HTTP status code (use backticks: `` `http.statusCode` ``). Often treated as string—prefer `LIKE '5%'` over `>= 500`. |
| `httpResponseCode` | HTTP status code (legacy alias, same data as `http.statusCode`) |
| `request.method` | HTTP method (GET, POST, etc.) |
| `request.route.path` | **custom** — Route pattern (e.g. `/events/{eventId}/auth`). Added by app middleware. |
| `request.uri` | Request path (standard NR attribute, does not include host/query) |
| `request.url` | **custom** — Full request URL. Added by app instrumentation. |
| `request.headers.userAgent` | User-Agent header (use backticks) |
| `request.headers.referer` | Referer header |
| `response.status` | Response status (string, e.g. `LIKE '4%'`) |
| `response.statusCode` | **custom** — Response status code (use backticks). Standard equivalent is `response.status`. |
| `host` | APM "host" name (often pod/node identity in Kubernetes) |
| `clusterName` | **K8s integration** — Cluster name (auto-added by NR K8s integration) |
| `entityGuid` | Entity GUID |
| `name` | Transaction name (useful for FACET) |
| `timestamp` | Event timestamp (useful in filter predicates: `WHERE timestamp IS NOT NULL`) |
| `auth.user.id` | **custom** — Authenticated user ID (useful for per-user FACET) |

### APM - TransactionError
Error events from instrumented services. Often queried together: `FROM Transaction, TransactionError`.

| Field | Description |
|-------|-------------|
| `appName` | Application name |
| `error.message` | Error message (use backticks: `` `error.message` ``) |
| `error.expected` | Whether error is expected (use backticks) |
| `error.class` | Error type/class |
| `http.statusCode` | HTTP status code (use backticks) |
| `httpResponseCode` | HTTP status code (legacy alias) |
| `transactionName` | Transaction that errored |
| `clusterName` | **K8s integration** — Cluster name |
| `request.uri` | Request path |
| `request.headers.referer` | Referer header (used in cross-region checks) |

### Kubernetes - K8sContainerSample
Container-level metrics from the NR Kubernetes integration. All fields below are standard NR K8s integration attributes.

| Field | Description |
|-------|-------------|
| `clusterName` | Cluster name |
| `deploymentName` | Deployment name (WHERE / FACET) |
| `podName` | Pod name |
| `containerName` | Container name |
| `containerImage` | Container image |
| `status` | Container status |
| `isReady` | Readiness state (0/1; e.g. `WHERE isReady = 0`) |
| `restartCount` | Cumulative restart count (use with `derivative()`) |
| `restartCountDelta` | Restart count delta per sample |
| `cpuUsedCores` | CPU usage (cores) |
| `memoryUsedBytes` | Memory usage (bytes) |

### Kubernetes - K8sPodSample
Pod-level metrics. All fields below are standard NR K8s integration attributes.

| Field | Description |
|-------|-------------|
| `clusterName` | Cluster name |
| `deploymentName` | Deployment name |
| `podName` | Pod name |
| `displayName` | Display name (useful with `uniqueCount()`) |
| `namespace` | Kubernetes namespace |
| `net.rxBytesPerSecond` | Network receive throughput (bytes/s) |

### Kubernetes - K8sNodeSample
Node-level metrics. All fields below are standard NR K8s integration attributes.

| Field | Description |
|-------|-------------|
| `clusterName` | Cluster name |
| `nodeName` | Node name |
| `allocatableMemoryUtilization` | Memory utilization % |

### Infrastructure - InfrastructureEvent
Host and Kubernetes events. All fields below are standard NR infrastructure attributes.

| Field | Description |
|-------|-------------|
| `category` | Event category (`'kubernetes'`) |
| `event.reason` | Event reason (`OOMKilling`, etc.) |
| `event.message` | Event message (use `capture()` to extract fields) |
| `clusterName` | Cluster name |

### Custom Events — app-specific

These event types are **custom** — sent by application code. They will not exist in other environments. Replace or remove for your own services.

| Event Type | Key Fields | Description |
|------------|------------|-------------|
| `Counter` | `counterName`, `status`, `limited` | Application counters (DPL checks, rate limiting, etc.) |
| `Latency` | `appName`, `clusterName`, `counterName`, `delay` | Application latency measurements |
| `streamEvent` | `name`, `` `socket.id` ``, `` `subscriptions.events` `` | Stream server events |

### AWS Metrics (via Cloud Integration)
AWS metrics arrive in the `Metric` event type with service-specific fields.

| Metric | Description |
|--------|-------------|
| `aws.rds.CPUUtilization` | RDS CPU % |
| `aws.rds.DatabaseConnections` | RDS connections |
| `aws.rds.AuroraBinlogReplicaLag` | Aurora replication lag |
| `aws.rds.DBLoad` | RDS database load |
| `aws.rds.EngineUptime` | RDS engine uptime |
| `aws.sqs.ApproximateNumberOfMessagesVisible` | SQS queue depth |
| `aws.ec2.CPUUtilization` | EC2 CPU % |
| `aws.applicationelb.HealthyHostCount` | ALB healthy targets |
| `aws.lambda.Errors` | Lambda error count |
| `aws.lambda.Invocations` | Lambda invocations |

Labels: `aws.rds.DBInstanceIdentifier`, `aws.sqs.QueueName`, `aws.lambda.FunctionName`, `aws.region`, `aws.es.DomainName`

Metric event also carries APM timeslice data: `metricTimesliceName`, `newrelic.timeslice.value`, `entity.guid`, `entity.name`.

### Synthetics - SyntheticCheck
Results from synthetic monitors.

| Field | Description |
|-------|-------------|
| `monitorName` | Monitor name |
| `result` | SUCCESS or FAILED |
| `duration` | Check duration (ms) |
| `locationLabel` | Check location |
| `type` | Monitor type (SIMPLE, BROWSER, etc.) |

## Common Queries

### APM Error Rate
```bash
./scripts/query.sh "SELECT percentage(count(*), WHERE error) FROM Transaction WHERE appName = '<app-name>' FACET clusterName SINCE 1 HOUR AGO TIMESERIES"
```

### APM Error Rate (from Transaction + TransactionError)
```bash
./scripts/query.sh "SELECT filter(count(*), WHERE \`error.message\` IS NOT NULL)*100 / filter(count(*), WHERE duration IS NOT NULL) FROM Transaction, TransactionError WHERE appName = '<app-name>' SINCE 1 HOUR AGO TIMESERIES"
```

### APM Latency P99 (milliseconds)
```bash
./scripts/query.sh "SELECT percentile(duration * 1000, 99) AS 'Percentile' FROM Transaction WHERE appName = '<app-name>' SINCE 1 HOUR AGO TIMESERIES EXTRAPOLATE"
```

### APM Average Response Time (milliseconds)
```bash
./scripts/query.sh "SELECT average(duration) * 1000 FROM Transaction WHERE appName = '<app-name>' FACET clusterName SINCE 1 HOUR AGO TIMESERIES"
```

### APM Throughput
```bash
./scripts/query.sh "SELECT rate(count(*), 1 minute) FROM Transaction WHERE appName = '<app-name>' SINCE 1 HOUR AGO TIMESERIES"
```

### APM Error Rate by App
```bash
./scripts/query.sh "SELECT percentage(count(*), WHERE error) FROM Transaction FACET appName, clusterName SINCE 1 HOUR AGO"
```

### HTTP 5xx Rate
```bash
./scripts/query.sh "SELECT percentage(count(*), WHERE \`http.statusCode\` LIKE '5%') FROM Transaction WHERE appName = '<app-name>' SINCE 1 HOUR AGO TIMESERIES"
```

### HTTP 4xx Rate
```bash
./scripts/query.sh "SELECT percentage(count(*), WHERE \`http.statusCode\` LIKE '4%') FROM Transaction WHERE appName = '<app-name>' SINCE 1 HOUR AGO TIMESERIES"
```

### HTTP 5xx by Route
```bash
./scripts/query.sh "SELECT percentage(count(*), WHERE \`http.statusCode\` LIKE '5%') FROM Transaction WHERE appName = '<app-name>' FACET \`request.route.path\`, clusterName SINCE 1 HOUR AGO"
```

### Error Rate per Host
```bash
./scripts/query.sh "SELECT filter(COUNT(*), WHERE \`error.message\` IS NOT NULL)*100 / filter(COUNT(*), WHERE duration IS NOT NULL) FROM Transaction, TransactionError FACET host, clusterName SINCE 1 HOUR AGO"
```

### Error Count by Message
```bash
./scripts/query.sh "SELECT count(*) FROM TransactionError WHERE appName = '<app-name>' FACET \`error.message\` SINCE 1 HOUR AGO"
```

### Container Restarts
```bash
./scripts/query.sh "SELECT sum(restartCountDelta) FROM K8sContainerSample WHERE clusterName LIKE '%prod%' FACET podName, containerName SINCE 1 HOUR AGO"
```

### Container Restarts (derivative)
```bash
./scripts/query.sh "SELECT derivative(restartCount, 2 minute) AS 'Restarts' FROM K8sContainerSample WHERE clusterName LIKE '%prod%' FACET clusterName, podName SINCE 1 HOUR AGO"
```

### Container CPU Usage
```bash
./scripts/query.sh "SELECT average(cpuUsedCores) FROM K8sContainerSample WHERE clusterName LIKE '%prod%' FACET podName SINCE 30 MINUTES AGO TIMESERIES"
```

### Container Memory Usage
```bash
./scripts/query.sh "SELECT average(memoryUsedBytes / 1e6) AS 'Memory MB' FROM K8sContainerSample WHERE clusterName LIKE '%prod%' FACET podName SINCE 30 MINUTES AGO TIMESERIES"
```

### Pods Not Ready
```bash
./scripts/query.sh "SELECT percentage(uniqueCount(podName), WHERE isReady = 0) AS unavailablePods FROM K8sContainerSample WHERE clusterName LIKE '%prod%' FACET clusterName, deploymentName SINCE 10 MINUTES AGO"
```

### Pod Network Throughput
```bash
./scripts/query.sh "SELECT average(net.rxBytesPerSecond) FROM K8sPodSample WHERE clusterName LIKE '%prod%' AND deploymentName = '<deployment>' FACET podName SINCE 30 MINUTES AGO TIMESERIES"
```

### OOMKilled Events
```bash
./scripts/query.sh "SELECT count(*) FROM InfrastructureEvent WHERE category = 'kubernetes' AND event.reason = 'OOMKilling' FACET clusterName, capture(event.message, r'^.*Killed\\ process\\ \\d+\\ \\((?P<processName>\\w+)\\) total-vm:.*$') SINCE 1 DAY AGO"
```

### RDS CPU Utilization
```bash
./scripts/query.sh "SELECT average(aws.rds.CPUUtilization) FROM Metric FACET aws.rds.DBInstanceIdentifier SINCE 1 HOUR AGO TIMESERIES"
```

### SQS Dead Letter Queue Depth
```bash
./scripts/query.sh "SELECT average(aws.sqs.ApproximateNumberOfMessagesVisible) FROM Metric WHERE aws.sqs.QueueName LIKE '%deadletter%' FACET aws.sqs.QueueName SINCE 1 HOUR AGO TIMESERIES"
```

### Lambda Error Rate
```bash
./scripts/query.sh "SELECT sum(aws.lambda.Errors) FROM Metric FACET aws.lambda.FunctionName SINCE 1 HOUR AGO TIMESERIES"
```

### Synthetics Failures
```bash
./scripts/query.sh "SELECT count(*) FROM SyntheticCheck WHERE result = 'FAILED' FACET monitorName SINCE 1 DAY AGO"
```

## Workflow

1. **Fetch to temp file** (use `--raw` for full JSON):
   ```bash
   ./scripts/query.sh --raw "SELECT average(duration), percentile(duration, 95) FROM Transaction WHERE appName = '<app-name>' SINCE 1 HOUR AGO TIMESERIES" > /tmp/nr-metrics.json
   ```

2. **Analyze with jq**:
   ```bash
   # Extract results
   jq '.data.actor.account.nrql.results' /tmp/nr-metrics.json

   # Get timeseries values
   jq '[.data.actor.account.nrql.results[] | {time: .beginTimeSeconds, avg: .average, p95: .percentile}]' /tmp/nr-metrics.json

   # Find max value
   jq '[.data.actor.account.nrql.results[].average] | max' /tmp/nr-metrics.json
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
            { "average": 0.123, "facet": "my-app" }
          ]
        }
      }
    }
  }
}
```

For TIMESERIES queries, each bucket includes:
```json
{
  "beginTimeSeconds": 1706097600,
  "endTimeSeconds": 1706097660,
  "average": 0.123
}
```

## Time Formats in NRQL

- Relative: `SINCE 30 MINUTES AGO`, `SINCE 1 HOUR AGO`, `SINCE 6 HOURS AGO`, `SINCE 1 DAY AGO`, `SINCE TODAY`
- Absolute: `SINCE '2024-01-24 12:00:00' UNTIL '2024-01-24 13:00:00'`
- With TIMESERIES: `TIMESERIES`, `TIMESERIES 1 MINUTE`, `TIMESERIES 5 MINUTES`, `TIMESERIES AUTO`
- COMPARE WITH: `SINCE 1 HOUR AGO COMPARE WITH 1 HOUR AGO` for period-over-period

## Best Practices

1. **Use TIMESERIES for trends** - Shows time-bucketed data for visualization
2. **FACET for breakdown** - Split metrics by dimension (appName, podName, etc.)
3. **Use percentage() for error rates** - More accurate than manual calculation
4. **Combine with COMPARE WITH** - Period-over-period comparison built into NRQL
5. **Use rate() for throughput** - Normalizes counts to per-second or per-minute
6. **Backtick dotted fields** - Fields with dots (e.g. `` `http.statusCode` ``) need backticks in NRQL
