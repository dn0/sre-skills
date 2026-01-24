#!/bin/bash
# Query GCP Cloud Logging with JSON output (for exploring unknown log structures)
# Usage: ./query-json.sh PROJECT FILTER [LIMIT] [FRESHNESS]
#
# Examples:
#   ./query-json.sh my-project 'resource.type="http_load_balancer"' 5
#   ./query-json.sh my-project 'resource.type="k8s_container"' 10 1h

set -euo pipefail

PROJECT="${1:?Usage: $0 PROJECT FILTER [LIMIT] [FRESHNESS]}"
FILTER="${2:?Usage: $0 PROJECT FILTER [LIMIT] [FRESHNESS]}"
LIMIT="${3:-10}"
FRESHNESS="${4:-1d}"

gcloud logging read "$FILTER" \
  --project="$PROJECT" \
  --limit="$LIMIT" \
  --freshness="$FRESHNESS" \
  --format=json
