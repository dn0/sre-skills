#!/bin/bash
# Query Loki logs via Grafana API
# Usage: ./query.sh DATASOURCE QUERY [RANGE_MINUTES] [LIMIT]
#
# Requires: GRAFANA_URL, GRAFANA_API_KEY environment variables
#
# Examples:
#   ./query.sh loki-prod '{namespace="my-app"}' 30 100
#   ./query.sh loki-prod '{job="kube-events", type="Warning"}' 60 50

set -euo pipefail

DATASOURCE="${1:?Usage: $0 DATASOURCE QUERY [RANGE_MINUTES] [LIMIT]}"
QUERY="${2:?Usage: $0 DATASOURCE QUERY [RANGE_MINUTES] [LIMIT]}"
RANGE_MINUTES="${3:-30}"
LIMIT="${4:-100}"

: "${GRAFANA_URL:?GRAFANA_URL environment variable is required}"
: "${GRAFANA_API_KEY:?GRAFANA_API_KEY environment variable is required}"

END=$(date +%s)000
START=$(( $(date +%s) - RANGE_MINUTES * 60 ))000

# Escape query for JSON
ESCAPED_QUERY=$(echo "$QUERY" | sed 's/\\/\\\\/g; s/"/\\"/g')

curl -sS -X POST -H "Authorization: Bearer $GRAFANA_API_KEY" \
  -H "Content-Type: application/json" \
  "${GRAFANA_URL}/api/ds/query" \
  -d '{
    "queries": [{
      "refId": "A",
      "datasource": {"type": "loki", "uid": "'"$DATASOURCE"'"},
      "expr": "'"$ESCAPED_QUERY"'",
      "queryType": "range",
      "maxLines": '"$LIMIT"'
    }],
    "from": "'"$START"'",
    "to": "'"$END"'"
  }'
