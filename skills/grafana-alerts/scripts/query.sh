#!/bin/bash
# Query alerts from Alertmanager or Prometheus via Grafana API
# Usage: ./query.sh DATASOURCE [STATE] [TYPE]
#
# TYPE options:
#   auto         - Auto-detect based on datasource type (default)
#   alertmanager - Query Alertmanager API (alerts sent to alertmanager)
#   prometheus   - Query Prometheus API (alerts from rules)
#
# STATE options:
#   Alertmanager:
#     all      - All alerts (default)
#     active   - Only firing alerts (not silenced/inhibited)
#     silenced - Only silenced alerts
#   Prometheus:
#     alerts   - Only firing/pending alerts (default)
#     rules    - All configured rules (alerting and recording)
#
# Requires: GRAFANA_URL, GRAFANA_API_KEY environment variables
#
# Examples:
#   ./query.sh alertmanager-prod active
#   ./query.sh prometheus-prod
#   ./query.sh prometheus-prod rules
#   ./query.sh mimir-prod "" prometheus

set -euo pipefail

DATASOURCE="${1:?Usage: $0 DATASOURCE [STATE] [TYPE]}"
STATE="${2:-all}"
TYPE="${3:-auto}"

: "${GRAFANA_URL:?GRAFANA_URL environment variable is required}"
: "${GRAFANA_API_KEY:?GRAFANA_API_KEY environment variable is required}"

# Auto-detect datasource type if needed
if [ "$TYPE" = "auto" ]; then
  DS_TYPE=$(curl -sS -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "${GRAFANA_URL}/api/datasources/uid/${DATASOURCE}" | jq -r '.type // empty')

  if [ "$DS_TYPE" = "alertmanager" ]; then
    TYPE="alertmanager"
  elif [ "$DS_TYPE" = "prometheus" ] || [ "$DS_TYPE" = "loki" ]; then
    TYPE="prometheus"
  else
    echo "Error: Unknown datasource type '$DS_TYPE' for '$DATASOURCE'" >&2
    exit 1
  fi
fi

if [ "$TYPE" = "alertmanager" ]; then
  # Alertmanager API
  case "$STATE" in
    active)
      PARAMS="?silenced=false&inhibited=false&active=true"
      ;;
    silenced)
      PARAMS="?silenced=true"
      ;;
    all|*)
      PARAMS=""
      ;;
  esac
  curl -sS -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "${GRAFANA_URL}/api/alertmanager/${DATASOURCE}/api/v2/alerts${PARAMS}"
else
  # Prometheus API
  if [ "$STATE" = "rules" ]; then
    # All configured rules (alerting and recording)
    curl -sS -H "Authorization: Bearer $GRAFANA_API_KEY" \
      "${GRAFANA_URL}/api/prometheus/${DATASOURCE}/api/v1/rules"
  else
    # Firing/pending alerts only
    curl -sS -H "Authorization: Bearer $GRAFANA_API_KEY" \
      "${GRAFANA_URL}/api/prometheus/${DATASOURCE}/api/v1/alerts"
  fi
fi
