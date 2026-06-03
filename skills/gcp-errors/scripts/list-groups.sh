#!/bin/bash
# List error groups (with stats) from GCP Error Reporting
# Usage: ./list-groups.sh PROJECT [SERVICE] [PERIOD] [STATUS] [LIMIT] [FORMAT]
#
# PERIOD: 1h, 6h, 1d (default), 1w, 30d
# STATUS: open, acknowledged, resolved, muted, all (default) — filtered client-side
# FORMAT: json (default), summary
#
# Examples:
#   ./list-groups.sh my-project
#   ./list-groups.sh my-project web
#   ./list-groups.sh my-project web 6h
#   ./list-groups.sh my-project '' 1w open 100 summary
#   ./list-groups.sh my-project web 1d all 50 summary

set -euo pipefail

PROJECT="${1:?Usage: $0 PROJECT [SERVICE] [PERIOD] [STATUS] [LIMIT] [FORMAT]}"
SERVICE="${2:-}"
PERIOD="${3:-1d}"
STATUS="${4:-all}"
LIMIT="${5:-20}"
FORMAT="${6:-json}"

case "$PERIOD" in
    1h)  API_PERIOD="PERIOD_1_HOUR" ;;
    6h)  API_PERIOD="PERIOD_6_HOURS" ;;
    1d)  API_PERIOD="PERIOD_1_DAY" ;;
    1w)  API_PERIOD="PERIOD_1_WEEK" ;;
    30d) API_PERIOD="PERIOD_30_DAYS" ;;
    *)   echo "Error: PERIOD must be 1h, 6h, 1d, 1w, or 30d" >&2; exit 1 ;;
esac

case "$STATUS" in
    open|acknowledged|resolved|muted|all) ;;
    *) echo "Error: STATUS must be open, acknowledged, resolved, muted, or all" >&2; exit 1 ;;
esac

case "$FORMAT" in
    json|summary) ;;
    *) echo "Error: FORMAT must be json or summary" >&2; exit 1 ;;
esac

TOKEN=$(gcloud auth print-access-token)

QS="timeRange.period=${API_PERIOD}&pageSize=${LIMIT}&order=COUNT_DESC"
if [[ -n "$SERVICE" ]]; then
    ENCODED_SERVICE=$(printf '%s' "$SERVICE" | python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""))')
    QS="${QS}&serviceFilter.service=${ENCODED_SERVICE}"
fi

RESPONSE=$(curl -fsS -H "Authorization: Bearer $TOKEN" \
    "https://clouderrorreporting.googleapis.com/v1beta1/projects/${PROJECT}/groupStats?${QS}")

# Client-side resolution status filter — the groupStats API doesn't expose it as a query param.
if [[ "$STATUS" != "all" ]]; then
    STATUS_UPPER=$(printf '%s' "$STATUS" | tr '[:lower:]' '[:upper:]')
    RESPONSE=$(printf '%s' "$RESPONSE" | STATUS_UPPER="$STATUS_UPPER" python3 -c '
import json, os, sys
target = os.environ["STATUS_UPPER"]
data = json.load(sys.stdin)
data["errorGroupStats"] = [
    g for g in data.get("errorGroupStats", [])
    if g.get("group", {}).get("resolutionStatus", "OPEN") == target
]
print(json.dumps(data))
')
fi

if [[ "$FORMAT" == "json" ]]; then
    printf '%s\n' "$RESPONSE"
else
    printf '%s' "$RESPONSE" | python3 -c '
import json, sys
data = json.load(sys.stdin)
groups = data.get("errorGroupStats", [])
if not groups:
    print("(no error groups)")
    sys.exit(0)
for i, g in enumerate(groups, 1):
    grp = g.get("group", {})
    rep = g.get("representative", {})
    status = grp.get("resolutionStatus", "OPEN")
    issues = [t.get("url", "") for t in grp.get("trackingIssues", [])]
    count = g.get("count", "?")
    svc = rep.get("serviceContext", {}).get("service", "?")
    first_msg = (rep.get("message", "") or "").split("\n", 1)[0][:160]
    group_id = grp.get("groupId", "?")
    print(f"[{i}] {group_id}")
    print(f"    {status:<13s} count={count:>8}  svc={svc}")
    print(f"    {first_msg}")
    for u in issues:
        print(f"    issue: {u}")
    print()
'
fi
