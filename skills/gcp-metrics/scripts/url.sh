#!/bin/bash
# Generate Metrics Explorer URL for a PromQL query
# Usage: ./url.sh PROJECT QUERY [DURATION]
#
# Examples:
#   ./url.sh my-project 'rate({"__name__"="kubernetes.io/container/cpu/core_usage_time"}[5m])' PT30M
#   ./url.sh my-project 'up' PT1H

set -euo pipefail

PROJECT="${1:?Usage: $0 PROJECT QUERY [DURATION]}"
QUERY="${2:?Usage: $0 PROJECT QUERY [DURATION]}"
DURATION="${3:-PT1H}"

# Build pageState JSON with proper escaping using jq (-c for compact output)
PAGE_STATE=$(jq -cn --arg query "$QUERY" '{"xyChart":{"dataSets":[{"plotType":"LINE","prometheusQuery":$query}]}}')

# URL encode via stdin to avoid shell escaping issues
ENCODED_STATE=$(printf '%s' "$PAGE_STATE" | python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.stdin.read()))")

echo "https://console.cloud.google.com/monitoring/metrics-explorer;duration=${DURATION}?project=${PROJECT}&pageState=${ENCODED_STATE}"
