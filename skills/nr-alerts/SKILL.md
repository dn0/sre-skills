---
name: nr-alerts
description: Query New Relic alert policies, conditions, and issues/incidents. Use when checking alert status, investigating open incidents, reviewing alert configurations, or listing policies. Generates Alerts UI URLs for humans.
---

# New Relic Alerts Skill

Query alert policies, conditions, and issues/incidents from New Relic via the NerdGraph API.

## Requirements

Environment variables:
- `NEW_RELIC_API_KEY` - User API key (NRAK prefix)
- `NEW_RELIC_ACCOUNT_ID` - Numeric account ID

Tooling (either works; the CLI is preferred when present):
- [`newrelic` CLI](https://github.com/newrelic/newrelic-cli) - reads the two env vars above automatically (uses `newrelic nerdgraph query`)
- or `curl` + `jq` - used as the fallback transport

Both paths also need `python3` for result formatting.

## Scripts

Both data scripts run their GraphQL via the `newrelic` CLI when installed, otherwise the NerdGraph API over curl+jq — same results either way. By default they print a **markdown table** (plus a count summary on stderr); pass `--raw` to get the underlying JSON **array** for `jq` pipelines or saving to a file.

### Query issues/incidents
```bash
./scripts/query.sh [--raw] [STATE] [LIMIT]
```
- **STATE**: `open` (default), `closed`, `all`
- **LIMIT**: max issues to show/return (default 50; applied client-side)
- Default output: Alerts UI URL + a table (Priority, State, Activated, Incidents, Title, Policy).
- `--raw`: the issues array as JSON.

### List alert policies
```bash
./scripts/list-policies.sh [--raw] [SEARCH_NAME]
```
- **SEARCH_NAME**: **exact** policy name — `policiesSearch` matches the full name, not a substring (see [Gotchas](#gotchas)).
- Default output: a table (id, name, incidentPreference) + `N of TOTAL` summary on stderr.
- `--raw`: the policies array as JSON.

### Generate Alerts UI URL
```bash
./scripts/url.sh [TYPE] [ID]
```
- **TYPE**: `overview` (default), `issue`, `policy`, `condition`
- Unlike logs/metrics query links, these are **stable ID-based URLs** that work when pasted — no server-side share state needed.

## Common Queries

### Get open/firing issues (table)
```bash
./scripts/query.sh open
```

### Get open issues with details (JSON)
```bash
./scripts/query.sh --raw open | jq -r '.[] | "Issue: \(.title | join("; "))\nPriority: \(.priority)\nPolicy: \(.policyName | join("; "))\nCondition: \(.conditionName | join("; "))\nOpen since: \(.activatedAt)\n"'
```

### Get recently closed issues
```bash
./scripts/query.sh closed 20
```

### List all alert policies
```bash
./scripts/list-policies.sh
```

### Look up a policy by exact name
```bash
# NOTE: exact match, not substring — pass the full policy name.
./scripts/list-policies.sh "dbf-production - OOMKillWarning"
```

### Filter issues by priority
```bash
./scripts/query.sh --raw open | jq '[.[] | select(.priority == "CRITICAL")]'
```

### Filter issues by policy name (policyName is an array)
```bash
./scripts/query.sh --raw open | jq '[.[] | select(any(.policyName[]?; contains("production")))]'
```

## Workflow

1. **Check for open issues** (`--raw` writes the issues array):
   ```bash
   ./scripts/query.sh --raw open > /tmp/nr-issues.json
   ```

2. **Analyze with jq** (the file is already the issues array):
   ```bash
   # Count open issues
   jq 'length' /tmp/nr-issues.json

   # List issue titles (title is an array)
   jq -r '.[].title | join("; ")' /tmp/nr-issues.json

   # Group by priority
   jq '[.[].priority] | group_by(.) | map({priority: .[0], count: length})' /tmp/nr-issues.json

   # Group by policy (policyName is an array)
   jq -r '[.[].policyName | join("; ")] | group_by(.) | map({policy: .[0], count: length})[] | "\(.count)\t\(.policy)"' /tmp/nr-issues.json | sort -rn

   # Get issue IDs for URLs
   jq -r '.[].issueId' /tmp/nr-issues.json
   ```

3. **List policies** (`--raw` writes the policies array):
   ```bash
   ./scripts/list-policies.sh --raw > /tmp/nr-policies.json

   # List policy names
   jq -r '.[] | "\(.id)\t\(.name)"' /tmp/nr-policies.json
   ```

4. **Generate URLs for humans**:
   ```bash
   # Alerts overview
   ./scripts/url.sh

   # Specific issue
   ./scripts/url.sh issue <issue-id>

   # Specific policy
   ./scripts/url.sh policy <policy-id>
   ```

## URLs for Humans

### Alerts overview
```
https://one.newrelic.com/alerts-ai?account=<account-id>
```

### Specific issue
```
https://one.newrelic.com/alerts-ai/issues/<issue-id>?account=<account-id>
```

### Specific policy
```
https://one.newrelic.com/alerts-ai/condition-builder/policy-entity?account=<account-id>&policyId=<policy-id>
```

`--raw` returns the underlying **array** directly (the scripts dig into the NerdGraph response and unwrap it; the `newrelic` CLI returns the same content minus the outer `data` wrapper).

### Issue array (`query.sh --raw`)
Note: `title`, `policyName`, and `conditionName` are **arrays of strings** (an issue can span conditions), and `activatedAt`/`closedAt` are epoch **milliseconds**.
```json
[
  {
    "issueId": "abc123-def456",
    "title": ["CPU usage too high on 'Production - High CPU'"],
    "priority": "CRITICAL",
    "state": "ACTIVATED",
    "activatedAt": 1706097600000,
    "closedAt": null,
    "policyName": ["Production Alerts"],
    "conditionName": ["High CPU"],
    "totalIncidents": 3,
    "entityGuids": ["MTIzNDU2..."],
    "sources": ["newrelic"],
    "origins": ["condition"]
  }
]
```

### Policy array (`list-policies.sh --raw`)
```json
[
  {
    "id": "12345",
    "name": "Production Alerts",
    "incidentPreference": "PER_CONDITION_AND_TARGET"
  }
]
```

## Gotchas

- **`policiesSearch` name is an exact match, not a substring.** Searching `"prod"` returns nothing even if policies contain "prod" in their names — pass the full policy name. (Policy names are not unique; the same name can return multiple ids across environments.)
- **Policy listing is paginated (~500 per page).** The default table's stderr summary shows `N of TOTAL`; if `TOTAL` exceeds `N`, the account has more policies than one page returns. Narrow with an exact `SEARCH_NAME`, or page via `nextCursor` for full coverage.
- **Issue `LIMIT` is applied client-side.** `aiIssues` returns a page of issues; the script truncates to `LIMIT` after fetching, so it bounds display, not the API call.

## Issue States

| State | Description |
|-------|-------------|
| `ACTIVATED` | Issue is currently open/firing |
| `CLOSED` | Issue has been resolved |
| `CREATED` | Issue was just created |
| `DEACTIVATED` | Issue was deactivated |

## Priority Levels

| Priority | Description |
|----------|-------------|
| `CRITICAL` | Immediate attention required |
| `HIGH` | Significant issue |
| `MEDIUM` | Moderate concern |
| `LOW` | Minor issue |

## Incident Preference

| Preference | Description |
|------------|-------------|
| `PER_POLICY` | One issue per policy |
| `PER_CONDITION` | One issue per condition |
| `PER_CONDITION_AND_TARGET` | One issue per condition + target |
