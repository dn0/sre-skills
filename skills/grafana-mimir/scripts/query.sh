#!/bin/bash
# Query Mimir/Prometheus metrics via Grafana API
# Usage: ./query.sh DATASOURCE QUERY [RANGE_MINUTES] [STEP_SECONDS]
#
# Requires: GRAFANA_URL, GRAFANA_API_KEY environment variables
#
# Examples:
#   ./query.sh mimir-prod 'up{namespace="my-app"}' 30 60
#   ./query.sh mimir-prod 'rate(http_requests_total[5m])' 60 15

set -euo pipefail

DATASOURCE="${1:?Usage: $0 DATASOURCE QUERY [RANGE_MINUTES] [STEP_SECONDS]}"
QUERY="${2:?Usage: $0 DATASOURCE QUERY [RANGE_MINUTES] [STEP_SECONDS]}"
RANGE_MINUTES="${3:-30}"
STEP_SECONDS="${4:-60}"

: "${GRAFANA_URL:?GRAFANA_URL environment variable is required}"
: "${GRAFANA_API_KEY:?GRAFANA_API_KEY environment variable is required}"

END=$(date +%s)000
START=$(( $(date +%s) - RANGE_MINUTES * 60 ))000
INTERVAL_MS=$((STEP_SECONDS * 1000))
MAX_POINTS=$((RANGE_MINUTES * 60 / STEP_SECONDS))

# Escape query for JSON
ESCAPED_QUERY=$(echo "$QUERY" | sed 's/\\/\\\\/g; s/"/\\"/g')

curl -sS -X POST -H "Authorization: Bearer $GRAFANA_API_KEY" \
  -H "Content-Type: application/json" \
  "${GRAFANA_URL}/api/ds/query" \
  -d '{
    "queries": [{
      "refId": "A",
      "datasource": {"type": "prometheus", "uid": "'"$DATASOURCE"'"},
      "expr": "'"$ESCAPED_QUERY"'",
      "range": true,
      "instant": false,
      "intervalMs": '"$INTERVAL_MS"',
      "maxDataPoints": '"$MAX_POINTS"'
    }],
    "from": "'"$START"'",
    "to": "'"$END"'"
  }'
