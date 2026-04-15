#!/bin/bash
# Query New Relic alert issues/incidents via NerdGraph API
# Usage: ./query.sh [STATE] [LIMIT]
#
# STATE: open, closed, all (default: open)
#
# Requires: NEW_RELIC_API_KEY, NEW_RELIC_ACCOUNT_ID environment variables
#
# Examples:
#   ./query.sh open
#   ./query.sh closed 50
#   ./query.sh all 100

set -euo pipefail

STATE="${1:-open}"
LIMIT="${2:-50}"

: "${NEW_RELIC_API_KEY:?NEW_RELIC_API_KEY environment variable is required}"
: "${NEW_RELIC_ACCOUNT_ID:?NEW_RELIC_ACCOUNT_ID environment variable is required}"

case "$STATE" in
    open)
        STATE_FILTER="ACTIVATED"
        ;;
    closed)
        STATE_FILTER="CLOSED"
        ;;
    all)
        STATE_FILTER=""
        ;;
    *)
        echo "Error: STATE must be 'open', 'closed', or 'all'" >&2
        exit 1
        ;;
esac

if [[ -n "$STATE_FILTER" ]]; then
    QUERY=$(jq -n \
      --argjson accountId "$NEW_RELIC_ACCOUNT_ID" \
      --arg state "$STATE_FILTER" \
      --argjson limit "$LIMIT" \
      '{
        query: "{ actor { account(id: \($accountId)) { aiIssues { issues(filter: { states: \($state) }, cursor: null) { issues { issueId title priority state activatedAt closedAt policyName conditionName totalIncidents entityGuids sources origins } nextCursor } } } } }"
      }')
else
    QUERY=$(jq -n \
      --argjson accountId "$NEW_RELIC_ACCOUNT_ID" \
      --argjson limit "$LIMIT" \
      '{
        query: "{ actor { account(id: \($accountId)) { aiIssues { issues(cursor: null) { issues { issueId title priority state activatedAt closedAt policyName conditionName totalIncidents entityGuids sources origins } nextCursor } } } } }"
      }')
fi

curl -sS -X POST https://api.newrelic.com/graphql \
  -H "Content-Type: application/json" \
  -H "API-Key: ${NEW_RELIC_API_KEY}" \
  -d "$QUERY"
