#!/bin/bash
# Query alerts/incidents from GCP Cloud Monitoring
# Usage: ./query.sh PROJECT [STATE] [LIMIT]
#
# STATE: open, closed, all (default: all)
#
# Examples:
#   ./query.sh my-project open
#   ./query.sh my-project closed 50
#   ./query.sh my-project all 100

set -euo pipefail

PROJECT="${1:?Usage: $0 PROJECT [STATE] [LIMIT]}"
STATE="${2:-all}"
LIMIT="${3:-100}"

case "$STATE" in
    open)
        FILTER="state=OPEN"
        ;;
    closed)
        FILTER="state=CLOSED"
        ;;
    all)
        FILTER=""
        ;;
    *)
        echo "Error: STATE must be 'open', 'closed', or 'all'" >&2
        exit 1
        ;;
esac

if [[ -n "$FILTER" ]]; then
    gcloud beta monitoring alerts list \
        --project="$PROJECT" \
        --filter="$FILTER" \
        --limit="$LIMIT" \
        --format=json
else
    gcloud beta monitoring alerts list \
        --project="$PROJECT" \
        --limit="$LIMIT" \
        --format=json
fi
