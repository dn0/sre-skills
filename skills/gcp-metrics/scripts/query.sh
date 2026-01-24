#!/bin/bash
# Query GCP Monitoring metrics using PromQL via Prometheus API
# Usage: ./query.sh PROJECT QUERY [START_OFFSET_SECONDS] [END_OFFSET_SECONDS] [STEP_SECONDS]
#
# Examples:
#   ./query.sh my-project 'up' 3600 0 60
#   ./query.sh my-project 'rate({"__name__"="kubernetes.io/container/cpu/core_usage_time"}[5m])' 1800

set -euo pipefail

PROJECT="${1:?Usage: $0 PROJECT QUERY [START_OFFSET] [END_OFFSET] [STEP]}"
QUERY="${2:?Usage: $0 PROJECT QUERY [START_OFFSET] [END_OFFSET] [STEP]}"
START_OFFSET="${3:-3600}"  # Default: 1 hour ago
END_OFFSET="${4:-0}"       # Default: now
STEP="${5:-60}"            # Default: 60 seconds

TOKEN=$(gcloud auth print-access-token)
END=$(date +%s)
END=$((END - END_OFFSET))
START=$((END - START_OFFSET))

ENCODED_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$QUERY'''))")

curl -s -H "Authorization: Bearer $TOKEN" \
  "https://monitoring.googleapis.com/v1/projects/${PROJECT}/location/global/prometheus/api/v1/query_range?query=${ENCODED_QUERY}&start=${START}&end=${END}&step=${STEP}"
