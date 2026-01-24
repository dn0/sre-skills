#!/bin/bash
# List available Loki data sources in Grafana
# Usage: ./list-datasources.sh
#
# Requires: GRAFANA_URL, GRAFANA_API_KEY environment variables

set -euo pipefail

: "${GRAFANA_URL:?GRAFANA_URL environment variable is required}"
: "${GRAFANA_API_KEY:?GRAFANA_API_KEY environment variable is required}"

curl -sS -H "Authorization: Bearer $GRAFANA_API_KEY" \
  "${GRAFANA_URL}/api/datasources" | \
  jq -r '.[] | select(.type == "loki") | "\(.uid)\t\(.name)"'
