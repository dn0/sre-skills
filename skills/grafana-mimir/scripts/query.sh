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

# Build JSON payload using jq to avoid shell escaping issues
PAYLOAD=$(jq -n \
  --arg datasource "$DATASOURCE" \
  --arg query "$QUERY" \
  --argjson intervalMs "$INTERVAL_MS" \
  --argjson maxPoints "$MAX_POINTS" \
  --arg start "$START" \
  --arg end "$END" \
  '{
    queries: [{
      refId: "A",
      datasource: {type: "prometheus", uid: $datasource},
      expr: $query,
      range: true,
      instant: false,
      intervalMs: $intervalMs,
      maxDataPoints: $maxPoints
    }],
    from: $start,
    to: $end
  }')

curl -sS -X POST -H "Authorization: Bearer $GRAFANA_API_KEY" \
  -H "Content-Type: application/json" \
  "${GRAFANA_URL}/api/ds/query" \
  -d "$PAYLOAD"
