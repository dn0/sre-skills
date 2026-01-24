#!/bin/bash
# Generate GCP Cloud Monitoring Alerting console URL
# Usage: ./url.sh PROJECT [TYPE] [ID]
#
# TYPE: overview (default), alert, policy
#
# Examples:
#   ./url.sh my-project                           # Alerting overview
#   ./url.sh my-project alert 0.nsxvqhqxb9ym      # Specific alert/incident
#   ./url.sh my-project policy 17435544969820093568  # Specific policy

set -euo pipefail

PROJECT="${1:?Usage: $0 PROJECT [TYPE] [ID]}"
TYPE="${2:-overview}"
ID="${3:-}"

case "$TYPE" in
    overview)
        echo "https://console.cloud.google.com/monitoring/alerting?project=${PROJECT}"
        ;;
    alert)
        if [[ -z "$ID" ]]; then
            echo "Error: alert ID required" >&2
            exit 1
        fi
        echo "https://console.cloud.google.com/monitoring/alerting/alerts/${ID}?project=${PROJECT}"
        ;;
    policy)
        if [[ -z "$ID" ]]; then
            echo "Error: policy ID required" >&2
            exit 1
        fi
        echo "https://console.cloud.google.com/monitoring/alerting/policies/${ID}?project=${PROJECT}"
        ;;
    *)
        echo "Error: TYPE must be 'overview', 'alert', or 'policy'" >&2
        exit 1
        ;;
esac
