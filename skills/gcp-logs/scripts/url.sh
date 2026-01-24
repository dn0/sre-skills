#!/bin/bash
# Generate Logs Explorer URL for a query
# Usage: ./url.sh PROJECT QUERY [DURATION]
#
# Examples:
#   ./url.sh my-project 'resource.type="http_load_balancer"' PT30M
#   ./url.sh my-project $'resource.type="k8s_container"\nresource.labels.pod_name:"my-app-"' PT1H

set -euo pipefail

PROJECT="${1:?Usage: $0 PROJECT QUERY [DURATION]}"
QUERY="${2:?Usage: $0 PROJECT QUERY [DURATION]}"
DURATION="${3:-PT1H}"

ENCODED_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$QUERY''', safe=''))")

echo "https://console.cloud.google.com/logs/query;query=${ENCODED_QUERY};duration=${DURATION}?project=${PROJECT}"
