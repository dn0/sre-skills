#!/bin/bash
# Query GCP Cloud Logging using gcloud
# Usage: ./query.sh PROJECT FILTER FORMAT_FIELDS [LIMIT] [FRESHNESS]
#
# Examples:
#   ./query.sh my-project 'resource.type="http_load_balancer"' 'timestamp,httpRequest.status,httpRequest.requestUrl' 100
#   ./query.sh my-project 'resource.type="k8s_container" AND severity>="ERROR"' 'timestamp,severity,textPayload' 500 1h

set -euo pipefail

PROJECT="${1:?Usage: $0 PROJECT FILTER FORMAT_FIELDS [LIMIT] [FRESHNESS]}"
FILTER="${2:?Usage: $0 PROJECT FILTER FORMAT_FIELDS [LIMIT] [FRESHNESS]}"
FORMAT_FIELDS="${3:?Usage: $0 PROJECT FILTER FORMAT_FIELDS [LIMIT] [FRESHNESS]}"
LIMIT="${4:-1000}"
FRESHNESS="${5:-1d}"

gcloud logging read "$FILTER" \
  --project="$PROJECT" \
  --limit="$LIMIT" \
  --freshness="$FRESHNESS" \
  --format="csv($FORMAT_FIELDS)"
