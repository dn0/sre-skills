#!/bin/bash
# List New Relic alert policies via NerdGraph API
# Usage: ./list-policies.sh [SEARCH_NAME]
#
# Requires: NEW_RELIC_API_KEY, NEW_RELIC_ACCOUNT_ID environment variables
#
# Examples:
#   ./list-policies.sh                  # List all policies
#   ./list-policies.sh "pagerduty"      # Search by name

set -euo pipefail

SEARCH="${1:-}"

: "${NEW_RELIC_API_KEY:?NEW_RELIC_API_KEY environment variable is required}"
: "${NEW_RELIC_ACCOUNT_ID:?NEW_RELIC_ACCOUNT_ID environment variable is required}"

if [[ -n "$SEARCH" ]]; then
    PAYLOAD=$(jq -n \
      --argjson accountId "$NEW_RELIC_ACCOUNT_ID" \
      --arg search "$SEARCH" \
      '{
        query: "{ actor { account(id: \($accountId)) { alerts { policiesSearch(searchCriteria: { name: \($search | tojson) }) { policies { id name incidentPreference } totalCount } } } } }"
      }')
else
    PAYLOAD=$(jq -n \
      --argjson accountId "$NEW_RELIC_ACCOUNT_ID" \
      '{
        query: "{ actor { account(id: \($accountId)) { alerts { policiesSearch { policies { id name incidentPreference } totalCount } } } } }"
      }')
fi

curl -sS -X POST https://api.newrelic.com/graphql \
  -H "Content-Type: application/json" \
  -H "API-Key: ${NEW_RELIC_API_KEY}" \
  -d "$PAYLOAD"
