#!/bin/bash
# Print New Relic Data exploration URL + NRQL to paste in the query console.
# Usage: ./url.sh NRQL
#
# Requires: NEW_RELIC_ACCOUNT_ID environment variable
#
# The unified query UI (2024+) usually ignores legacy ?state= deep links on
# /data-exploration/query-builder. Open the data-exploration URL, expand the
# bottom "Query your data" drawer, NRQL mode, paste the printed query, Run.
# For a shareable link that embeds the query, use "Copy query link" in the UI
# after running once.
#
# Examples:
#   ./url.sh "FROM Log SELECT * WHERE level = 'ERROR' SINCE 30 MINUTES AGO LIMIT 100"
#   ./url.sh "FROM Log SELECT count(*) FACET level SINCE 1 HOUR AGO"

set -euo pipefail

NRQL="${1:?Usage: $0 NRQL}"

: "${NEW_RELIC_ACCOUNT_ID:?NEW_RELIC_ACCOUNT_ID environment variable is required}"

# Pass variables as arguments to avoid shell escaping issues
python3 - "$NRQL" "$NEW_RELIC_ACCOUNT_ID" << 'EOF'
import json
import sys
import urllib.parse

nrql = sys.argv[1]
account_id = sys.argv[2]

print(f"Data exploration URL: https://one.newrelic.com/data-exploration?account={account_id}", flush=True)
print(flush=True)
print(nrql, flush=True)

legacy_state = json.dumps({"initialActiveInterface": "nrqlEditor", "initialNrqlValue": nrql})
legacy = (
    "https://one.newrelic.com/data-exploration/query-builder?"
    f"account={account_id}&state={urllib.parse.quote(legacy_state, safe='')}"
)

sys.stderr.write(
    "\nOpen the first URL, expand the bottom \"Query your data\" drawer, choose NRQL, "
    "paste the query above, then Run to see data.\n"
    "To get a single shareable link that includes the query: run once, then click "
    '"Copy query link" in the query console (team members need New Relic access).\n'
    "Docs: https://docs.newrelic.com/docs/query-your-data/explore-query-data/dashboards/share-charts-dashboards-internally/#share-your-charts-internally\n"
    f"\nLegacy ?state= link (often opens empty in newer UI):\n{legacy}\n\n"
)
EOF
