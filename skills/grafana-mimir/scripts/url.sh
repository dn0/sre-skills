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
# Pass variables as arguments to avoid shell escaping issues in heredoc
python3 - "$DATASOURCE" "$QUERY" "$RANGE" "$GRAFANA_URL" << 'EOF'
import urllib.parse
import json
import sys

datasource = sys.argv[1]
query = sys.argv[2]
range_from = sys.argv[3]
grafana_url = sys.argv[4]

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
