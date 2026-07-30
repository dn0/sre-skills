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

Tooling (either works; the CLI is preferred when present):
- [`newrelic` CLI](https://github.com/newrelic/newrelic-cli) - reads the two env vars above automatically
- or `curl` + `jq` - used as the fallback transport

Both paths also need `python3` for result formatting.

## Scripts

### Query metrics (NRQL)
```bash
./scripts/query.sh NRQL [TIMEOUT_SECONDS]
```

Runs the NRQL (via the `newrelic` CLI when installed, otherwise the NerdGraph API over curl+jq — same results either way), **copies the NRQL to the system clipboard** (macOS `pbcopy`, or `wl-copy` / `xclip` on Linux), prints **`Data exploration URL: https://one.newrelic.com/data-exploration?account=<numeric_account_id>`**, then prints **results**:

- **FACET aggregates** → **markdown table** (one column per facet dimension plus metric columns).
- **Other shapes** (timeseries, raw rows) → **indented JSON**.

Pass `--raw` as the first argument to get the **NRQL results array** as JSON (for `jq` pipelines or saving to a file). The array is the same list you would find under `data.actor.account.nrql.results` in a raw NerdGraph response — the script has already unwrapped it.

**Agents:** Copy the **Data exploration URL** line from script output verbatim—never replace the account id with placeholders like `${NEW_RELIC_ACCOUNT_ID}`.

### Generate Query Builder URL
```bash
./scripts/url.sh NRQL
```

Prints the Data exploration URL and the NRQL text (and copies the NRQL to the clipboard). Open that page, expand the bottom **Query your data** drawer, switch to NRQL, paste, and Run.

There is deliberately **no one-click deep link with the query embedded**. New Relic's "Copy query link" produces a shortened `onenr.io` URL that redirects to `.../unified-data-exploration/share?...&state=<UUID>`, where the query is stored server-side and referenced by an opaque UUID created by the UI — it cannot be constructed offline. For a shareable link, run the query once in the UI and click **Copy query link**. For a durable, greppable link you *can* generate programmatically, put the query on a **dashboard** (dashboards expose a stable `permalinkUrl` via NerdGraph).

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

## Discovering Metrics & Dimensions

The catalog below covers common event types, but **do not assume it is complete** — each account sends different data depending on which integrations are installed. When you don't know the exact event type, metric name, or attribute, discover it instead of guessing.

### Two data shapes

- **Event samples** — one event type per source (`Transaction`, `K8sContainerSample`, `SyntheticCheck`, …), where each attribute is a column. Query with `FROM <EventType> SELECT <attr>`.
- **Dimensional metrics** — everything in the single `Metric` event type, one row per `metricName` per reporting interval, with **dimensions** (labels) attached. Modern sources land here: **OpenTelemetry** (`k8s.*`, `otel.*`), **Prometheus** scrapes (`kube_*`, `node_*`, `container_*`), and **AWS Cloud integrations** (`aws.*`). Query with `FROM Metric WHERE metricName = '<name>'`.

Newer Kubernetes/EKS clusters typically report as **dimensional OTel metrics**, not `K8sXxxSample`. If a `*Sample` query returns nothing, look in `Metric`.

### Discovery queries

```bash
# What event types exist?
./scripts/query.sh "SHOW EVENT TYPES SINCE 1 day ago"

# What metric names match a keyword? (e.g. volume, cpu, disk, latency)
./scripts/query.sh "SELECT count(*) FROM Metric WHERE metricName LIKE '%volume%' FACET metricName SINCE 1 day ago LIMIT 200"

# What attributes/dimensions does an event type or metric carry?
./scripts/query.sh "SELECT keyset() FROM K8sContainerSample SINCE 1 day ago"
# keyset() can be unreliable when filtered; for a specific metric, read a sample row instead:
./scripts/query.sh --raw "SELECT * FROM Metric WHERE metricName = '<name>' SINCE 30 minutes ago LIMIT 1" | jq 'add | keys'

# What values does a dimension take? (find the right cluster/namespace label + value)
./scripts/query.sh "SELECT count(*) FROM Metric WHERE metricName = '<name>' FACET <dimension> SINCE 1 hour ago LIMIT 100"
```

### Dimensional-metric gotchas

- **Combine metrics with separate aggregators, not arithmetic inside one.** Each data point holds only one metric's value, so `latest(a - b)` is always null (no point has both `a` and `b`). Write `latest(a) - latest(b)` instead. Example — volume used %: `(latest(k8s.volume.capacity) - latest(k8s.volume.available)) / latest(k8s.volume.capacity) * 100`.
- **Don't filter on the "other" metric.** Adding `WHERE b IS NOT NULL` drops every data point that carries `a`, breaking `latest(a)`. Filter/aggregate each series independently and combine the aggregates.
- **Label names vary by integration.** OTel uses dotted names (`k8s.cluster.name`, `k8s.namespace.name`); `*Sample` events use camelCase (`clusterName`, `namespace`); Prometheus scrapes may use `cluster_name`. Discover the actual name (above) rather than assuming. Backtick dotted names that collide with NRQL syntax.
- **A metric may lack the label you want.** When it does, enumerate/scope with a companion metric that has it. For example, kubelet volume stats (`k8s.volume.*`) carry no PVC label and mix in `emptyDir`/`hostPath` volumes that mirror the node's root disk; the kube-state metrics `kube_persistentvolumeclaim_*` (labels `k8s.pvc.name`, `k8s.namespace.name`, `k8s.cluster.name`) give the real PVC inventory to scope against.

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

1. **Fetch to temp file** (`--raw` emits the results array):
   ```bash
   ./scripts/query.sh --raw "SELECT average(duration), percentile(duration, 95) FROM Transaction WHERE appName = '<app-name>' SINCE 1 HOUR AGO TIMESERIES" > /tmp/nr-metrics.json
   ```

2. **Analyze with jq** (the file is already the results array):
   ```bash
   # View results
   jq '.' /tmp/nr-metrics.json

   # Get timeseries values
   jq '[.[] | {time: .beginTimeSeconds, avg: .average, p95: .percentile}]' /tmp/nr-metrics.json

   # Find max value
   jq '[.[].average] | max' /tmp/nr-metrics.json
   ```

3. **Share with a human**: run `./scripts/url.sh` with the same NRQL — it prints the console URL and the NRQL to paste. For a shareable link, the human runs it once in the UI and clicks **Copy query link** (server-backed; not constructable offline).

## Response Structure

`--raw` returns the **results array** directly (the script unwraps NerdGraph's `data.actor.account.nrql.results` for you, and the `newrelic` CLI returns the same array natively):
```json
[
  { "average": 0.123, "facet": "my-app" }
]
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
