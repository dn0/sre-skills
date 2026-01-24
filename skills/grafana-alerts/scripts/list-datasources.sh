#!/bin/bash
# List data sources that can have alerts (Alertmanager, Prometheus/Mimir)
# Usage: ./list-datasources.sh
#
# Requires: GRAFANA_URL, GRAFANA_API_KEY environment variables

set -euo pipefail

: "${GRAFANA_URL:?GRAFANA_URL environment variable is required}"
: "${GRAFANA_API_KEY:?GRAFANA_API_KEY environment variable is required}"

echo "=== Alertmanager (alerts sent to alertmanager) ==="
curl -sS -H "Authorization: Bearer $GRAFANA_API_KEY" \
  "${GRAFANA_URL}/api/datasources" | \
  jq -r '.[] | select(.type == "alertmanager") | "\(.uid)\t\(.name)"'

echo ""
echo "=== Prometheus/Mimir (alerts from rules) ==="
curl -sS -H "Authorization: Bearer $GRAFANA_API_KEY" \
  "${GRAFANA_URL}/api/datasources" | \
  jq -r '.[] | select(.type == "prometheus") | "\(.uid)\t\(.name)"'
