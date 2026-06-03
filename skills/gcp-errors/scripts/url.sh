#!/bin/bash
# Generate GCP Error Reporting console URL
# Usage: ./url.sh PROJECT [TYPE] [GROUP_ID] [DURATION]
#
# TYPE: overview (default), group
# DURATION: ISO 8601 duration (PT1H, PT6H, P1D, P7D, P30D — default: PT1H)
#
# Examples:
#   ./url.sh my-project                                # Errors overview
#   ./url.sh my-project group CMy_2efZpKz-VA           # Specific error group
#   ./url.sh my-project group CMy_2efZpKz-VA PT6H      # Group with 6h time window

set -euo pipefail

PROJECT="${1:?Usage: $0 PROJECT [TYPE] [GROUP_ID] [DURATION]}"
TYPE="${2:-overview}"
GROUP_ID="${3:-}"
DURATION="${4:-PT1H}"

case "$TYPE" in
    overview)
        echo "https://console.cloud.google.com/errors?project=${PROJECT}&time=${DURATION}"
        ;;
    group)
        if [[ -z "$GROUP_ID" ]]; then
            echo "Error: GROUP_ID required for type 'group'" >&2
            exit 1
        fi
        echo "https://console.cloud.google.com/errors/detail/${GROUP_ID}?project=${PROJECT}&time=${DURATION}"
        ;;
    *)
        echo "Error: TYPE must be 'overview' or 'group'" >&2
        exit 1
        ;;
esac
