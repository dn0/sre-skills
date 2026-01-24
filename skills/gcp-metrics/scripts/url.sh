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

# Escape quotes for JSON
JSON_QUERY=$(echo "$QUERY" | sed 's/"/\\"/g')

# Build pageState JSON
PAGE_STATE='{"xyChart":{"dataSets":[{"plotType":"LINE","prometheusQuery":"'"${JSON_QUERY}"'"}]}}'

# URL encode
ENCODED_STATE=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$PAGE_STATE'''))")

echo "https://console.cloud.google.com/monitoring/metrics-explorer;duration=${DURATION}?project=${PROJECT}&pageState=${ENCODED_STATE}"
