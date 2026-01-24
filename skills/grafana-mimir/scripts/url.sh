#!/bin/bash
# Generate Grafana Explore URL for a Mimir/Prometheus query
# Usage: ./url.sh DATASOURCE QUERY [RANGE]
#
# Requires: GRAFANA_URL environment variable
#
# Examples:
#   ./url.sh mimir-prod 'rate(http_requests_total[5m])' 'now-30m'
#   ./url.sh mimir-prod 'up{namespace="my-app"}' 'now-1h'

set -euo pipefail

DATASOURCE="${1:?Usage: $0 DATASOURCE QUERY [RANGE]}"
QUERY="${2:?Usage: $0 DATASOURCE QUERY [RANGE]}"
RANGE="${3:-now-30m}"

: "${GRAFANA_URL:?GRAFANA_URL environment variable is required}"

# Use Python for proper JSON escaping and URL encoding
python3 << EOF
import urllib.parse
import json

datasource = """$DATASOURCE"""
query = """$QUERY"""
range_from = """$RANGE"""
grafana_url = """$GRAFANA_URL"""

panes = {
    "ahf": {
        "datasource": datasource,
        "queries": [{
            "refId": "A",
            "expr": query,
            "range": True,
            "datasource": {"type": "prometheus", "uid": datasource},
            "editorMode": "code",
            "legendFormat": "__auto"
        }],
        "range": {"from": range_from, "to": "now"}
    }
}

encoded_panes = urllib.parse.quote(json.dumps(panes))
print(f"{grafana_url}/explore?schemaVersion=1&panes={encoded_panes}&orgId=1")
EOF
