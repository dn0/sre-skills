---
name: gcp-errors
description: Query and manage GCP Error Reporting — list error groups, drill into events with stack traces, change resolution status (open/acknowledged/resolved/muted), and attach tracking issue URLs. Use during incident triage when an alert or report links to the Error Reporting console. Generates Error Reporting console URLs for humans.
---

# GCP Errors Skill

Triage errors from GCP Error Reporting: list error groups for a service, drill into a group to get stack traces and HTTP context, change resolution status, attach tracking issue links, and link humans to the console.

## Prerequisites

**GCP Project ID is required.** If the user has not provided one, ask before proceeding. All scripts require the project ID as the first argument.

**Authentication:** scripts use `gcloud auth print-access-token`, so `gcloud auth login` (or ADC) must be set up. The Error Reporting API (`clouderrorreporting.googleapis.com`) must be enabled on the project. `update-group.sh` requires write permission (`errorreporting.groups.update`).

## Scripts

### List error groups (start here)
```bash
./scripts/list-groups.sh PROJECT [SERVICE] [PERIOD] [STATUS] [LIMIT] [FORMAT]
```
- **SERVICE**: optional service name (e.g. `web`). Empty string = all services.
- **PERIOD**: `1h`, `6h`, `1d` (default), `1w`, `30d`
- **STATUS**: `open`, `acknowledged`, `resolved`, `muted`, `all` (default). Filtered client-side — the API does not expose `resolutionStatus` as a query param on `groupStats`.
- **LIMIT**: max groups to return (default `20`)
- **FORMAT**: `json` (default), `summary` (compact human-readable: group id, status, count, service, first message line, tracking issues)

### Fetch events for a specific group
```bash
./scripts/query.sh PROJECT GROUP_ID [PERIOD] [LIMIT] [SERVICE] [FORMAT]
```
- **GROUP_ID**: from `list-groups.sh` output (`.errorGroupStats[].group.groupId`)
- **FORMAT**: `json` (default), `summary` (dedups events by first line of the message and prints distinct patterns by frequency — useful for spotting subtypes inside one group)

### Get full metadata for one group
```bash
./scripts/get-group.sh PROJECT GROUP_ID
```
Returns the group resource including `resolutionStatus` and `trackingIssues`. Useful before and after `update-group.sh`.

### Update resolution status / attach a tracking issue
```bash
./scripts/update-group.sh PROJECT GROUP_ID STATUS [ISSUE_URL]
```
- **STATUS**: `open`, `acknowledged`, `resolved`, `muted` (case-insensitive)
- **ISSUE_URL**: optional. When given, **replaces** the group's tracking issues with `[{url: ISSUE_URL}]`. Omit to preserve existing tracking issues.

The API has no PATCH for groups, only PUT — the script does GET-then-PUT to preserve unrelated fields. Small race window if two writers update the same group concurrently; fine for human-driven triage.

### Generate Error Reporting console URL
```bash
./scripts/url.sh PROJECT [TYPE] [GROUP_ID] [DURATION]
```
- **TYPE**: `overview` (default), `group`
- **DURATION**: ISO 8601 (`PT1H` default, also `PT6H`, `P1D`, `P7D`, `P30D`)

## Common Queries

### Triage open errors for a service (compact summary)
```bash
./scripts/list-groups.sh <project-id> web 1d open 50 summary
```

### Top errors across all services last week (raw JSON for further filtering)
```bash
./scripts/list-groups.sh <project-id> '' 1w all 100 > /tmp/err-groups.json
```

### Find groups with no tracking issue
```bash
jq '[.errorGroupStats[] | select((.group.trackingIssues // []) == [])]' /tmp/err-groups.json
```

### Errors first seen since a release went out
```bash
./scripts/list-groups.sh <project-id> web 1w all 100 \
  | jq --arg since "2026-04-22T00:00:00Z" \
       '.errorGroupStats | map(select(.firstSeenTime >= $since))'
```

### Distinct patterns inside one group (deduplicated summary)
```bash
./scripts/query.sh <project-id> CMy_2efZpKz-VA 1d 100 '' summary
```

### Full stack traces for a group
```bash
./scripts/query.sh <project-id> CMy_2efZpKz-VA 1d 5 \
  | jq -r '.errorEvents[] | "=== \(.eventTime) ===\n\(.message)\n"'
```

### HTTP context (URL, method, status) for a group
```bash
./scripts/query.sh <project-id> CMy_2efZpKz-VA \
  | jq -r '.errorEvents[] | [.eventTime, .context.httpRequest.method, .context.httpRequest.responseStatusCode, .context.httpRequest.url] | @tsv'
```

### Affected versions for a group (which release introduced the error)
```bash
./scripts/query.sh <project-id> CMy_2efZpKz-VA 1w 200 \
  | jq -r '.errorEvents[].serviceContext.version' | sort -u
```

### Acknowledge and link a GitHub issue
```bash
./scripts/update-group.sh <project-id> CMy_2efZpKz-VA acknowledged https://github.com/org/repo/issues/42
```

### Mark resolved (preserve existing issue link)
```bash
./scripts/update-group.sh <project-id> CMy_2efZpKz-VA resolved
```

## Workflow

1. **List top open groups in summary form:**
   ```bash
   ./scripts/list-groups.sh <project-id> web 1d open 20 summary
   ```

2. **Drill into an interesting group to spot distinct patterns:**
   ```bash
   ./scripts/query.sh <project-id> <group-id> 1d 100 '' summary
   ```

3. **Pull full JSON when you need stack traces / HTTP context:**
   ```bash
   ./scripts/query.sh <project-id> <group-id> 1d 10 > /tmp/err-events.json
   jq -r '.errorEvents[0].message' /tmp/err-events.json   # first stack trace
   ```

4. **Acknowledge with a linked tracking issue:**
   ```bash
   ./scripts/update-group.sh <project-id> <group-id> acknowledged https://github.com/org/repo/issues/NUMBER
   ```

5. **Link the human to the console:**
   ```bash
   ./scripts/url.sh <project-id> group <group-id> PT6H
   ```

## URLs for Humans

### Error Reporting overview
```
https://console.cloud.google.com/errors?project=<project-id>&time=PT1H
```

### Specific error group
```
https://console.cloud.google.com/errors/detail/<group-id>?project=<project-id>&time=PT1H
```
The group ID is from `errorGroupStats[].group.groupId` (e.g. `CMy_2efZpKz-VA`).

## Response Structures

### Error group stats (from `list-groups.sh` in JSON mode)
```json
{
  "errorGroupStats": [
    {
      "group": {
        "name": "projects/<project>/groups/<group-id>",
        "groupId": "CMy_2efZpKz-VA",
        "resolutionStatus": "OPEN",
        "trackingIssues": [{ "url": "https://github.com/..." }]
      },
      "count": "3340",
      "firstSeenTime": "2026-04-15T08:21:32.455Z",
      "lastSeenTime": "2026-04-26T11:34:39Z",
      "affectedServices": [
        { "service": "project-history", "version": "...", "resourceType": "k8s_container" }
      ],
      "numAffectedServices": 1,
      "representative": {
        "eventTime": "...",
        "serviceContext": { "service": "...", "version": "...", "resourceType": "..." },
        "message": "<full stack trace>",
        "context": { "httpRequest": { "method": "...", "url": "...", "responseStatusCode": 500 } }
      }
    }
  ],
  "timeRangeBegin": "2026-04-25T11:44:30Z"
}
```

### Error events (from `query.sh` in JSON mode)
```json
{
  "errorEvents": [
    {
      "eventTime": "2026-04-26T11:34:39.972Z",
      "serviceContext": { "service": "...", "version": "...", "resourceType": "..." },
      "message": "<full stack trace, multi-line>",
      "context": {
        "httpRequest": { "method": "POST", "url": "/...", "responseStatusCode": 500, "remoteIp": "..." },
        "user": "..."
      }
    }
  ]
}
```

### Error group (from `get-group.sh` and `update-group.sh`)
```json
{
  "name": "projects/<project>/groups/<group-id>",
  "groupId": "CMy_2efZpKz-VA",
  "resolutionStatus": "ACKNOWLEDGED",
  "trackingIssues": [{ "url": "https://github.com/..." }]
}
```

## Reference

### Time periods (`PERIOD`)
| Value | Window |
|-------|--------|
| `1h`  | last 1h |
| `6h`  | last 6h |
| `1d`  | last 24h (default) |
| `1w`  | last 7d |
| `30d` | last 30d |

### Resolution status
| Value | Meaning |
|-------|---------|
| `open` | Active, not yet acknowledged |
| `acknowledged` | Seen by a human, fix in progress |
| `resolved` | Marked fixed (reopens if it recurs) |
| `muted` | Hidden from default views |
