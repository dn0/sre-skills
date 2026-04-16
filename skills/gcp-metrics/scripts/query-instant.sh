#!/bin/bash
# Instant query for GCP Monitoring metrics (single point in time)
# Usage: ./query-instant.sh PROJECT QUERY
#
# Examples:
#   ./query-instant.sh my-project 'up'
#   ./query-instant.sh my-project '{"__name__"="compute.googleapis.com/instance/cpu/utilization"}'

set -euo pipefail

PROJECT="${1:?Usage: $0 PROJECT QUERY}"
QUERY="${2:?Usage: $0 PROJECT QUERY}"

TOKEN=$(gcloud auth print-access-token)
ENCODED_QUERY=$(printf '%s' "$QUERY" | python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""))')

curl -fsS -H "Authorization: Bearer $TOKEN" \
  "https://monitoring.googleapis.com/v1/projects/${PROJECT}/location/global/prometheus/api/v1/query?query=${ENCODED_QUERY}"
