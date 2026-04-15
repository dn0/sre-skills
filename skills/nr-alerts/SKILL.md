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

## Scripts

### Query issues/incidents
```bash
./scripts/query.sh [STATE] [LIMIT]
```
- **STATE**: `open` (default), `closed`, `all`

### List alert policies
```bash
./scripts/list-policies.sh [SEARCH_NAME]
```

### Generate Alerts UI URL
```bash
./scripts/url.sh [TYPE] [ID]
```
- **TYPE**: `overview` (default), `issue`, `policy`, `condition`

## Common Queries

### Get open/firing issues
```bash
./scripts/query.sh open
```

### Get open issues with details
```bash
./scripts/query.sh open | jq -r '.data.actor.account.aiIssues.issues.issues[] | "Issue: \(.title)\nPriority: \(.priority)\nPolicy: \(.policyName)\nCondition: \(.conditionName)\nOpen since: \(.activatedAt)\n"'
```

### Get recently closed issues
```bash
./scripts/query.sh closed 20
```

### List all alert policies
```bash
./scripts/list-policies.sh
```

### Search policies by name
```bash
./scripts/list-policies.sh "pagerduty"
```

### Filter issues by priority
```bash
./scripts/query.sh open | jq '[.data.actor.account.aiIssues.issues.issues[] | select(.priority == "CRITICAL")]'
```

### Filter issues by policy name
```bash
./scripts/query.sh open | jq '[.data.actor.account.aiIssues.issues.issues[] | select(.policyName | contains("production"))]'
```

## Workflow

1. **Check for open issues**:
   ```bash
   ./scripts/query.sh open > /tmp/nr-issues.json
   ```

2. **Analyze with jq**:
   ```bash
   # Count open issues
   jq '.data.actor.account.aiIssues.issues.issues | length' /tmp/nr-issues.json

   # List issue titles
   jq -r '.data.actor.account.aiIssues.issues.issues[].title' /tmp/nr-issues.json

   # Group by priority
   jq '[.data.actor.account.aiIssues.issues.issues[] | .priority] | group_by(.) | map({priority: .[0], count: length})' /tmp/nr-issues.json

   # Group by policy
   jq -r '[.data.actor.account.aiIssues.issues.issues[] | .policyName] | group_by(.) | map({policy: .[0], count: length})[] | "\(.count)\t\(.policy)"' /tmp/nr-issues.json | sort -rn

   # Get issue IDs for URLs
   jq -r '.data.actor.account.aiIssues.issues.issues[].issueId' /tmp/nr-issues.json
   ```

3. **List policies**:
   ```bash
   ./scripts/list-policies.sh > /tmp/nr-policies.json

   # List policy names
   jq -r '.data.actor.account.alerts.policiesSearch.policies[] | "\(.id)\t\(.name)"' /tmp/nr-policies.json
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

## Response Structures

### Issue (from query.sh)
```json
{
  "data": {
    "actor": {
      "account": {
        "aiIssues": {
          "issues": {
            "issues": [
              {
                "issueId": "abc123-def456",
                "title": "CPU usage too high",
                "priority": "CRITICAL",
                "state": "ACTIVATED",
                "activatedAt": 1706097600000,
                "closedAt": null,
                "policyName": "Production Alerts",
                "conditionName": "High CPU",
                "totalIncidents": 3,
                "entityGuids": ["MTIzNDU2..."],
                "sources": ["newrelic"],
                "origins": ["condition"]
              }
            ],
            "nextCursor": null
          }
        }
      }
    }
  }
}
```

### Alert Policy (from list-policies.sh)
```json
{
  "data": {
    "actor": {
      "account": {
        "alerts": {
          "policiesSearch": {
            "policies": [
              {
                "id": "12345",
                "name": "Production Alerts",
                "incidentPreference": "PER_CONDITION_AND_TARGET"
              }
            ],
            "totalCount": 10
          }
        }
      }
    }
  }
}
```

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
