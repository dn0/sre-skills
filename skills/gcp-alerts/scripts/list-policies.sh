#!/bin/bash
# List GCP Cloud Monitoring alert policies
# Usage: ./list-policies.sh PROJECT [enabled|all]
#
# Examples:
#   ./list-policies.sh my-project enabled
#   ./list-policies.sh my-project all

set -euo pipefail

PROJECT="${1:?Usage: $0 PROJECT [enabled|all]}"
FILTER="${2:-enabled}"

if [[ "$FILTER" == "enabled" ]]; then
    gcloud monitoring policies list \
        --project="$PROJECT" \
        --filter="enabled=true" \
        --format=json
elif [[ "$FILTER" == "all" ]]; then
    gcloud monitoring policies list \
        --project="$PROJECT" \
        --format=json
else
    echo "Error: FILTER must be 'enabled' or 'all'" >&2
    exit 1
fi
