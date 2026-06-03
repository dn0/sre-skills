#!/bin/bash
# Fetch error events (with stack traces) for a specific group from GCP Error Reporting
# Usage: ./query.sh PROJECT GROUP_ID [PERIOD] [LIMIT] [SERVICE] [FORMAT]
#
# PERIOD: 1h, 6h, 1d (default), 1w, 30d
# FORMAT: json (default), summary
#         summary dedups events by the first line of the message and prints
#         distinct patterns sorted by frequency — useful for spotting subtypes
#         within a group.
#
# Examples:
#   ./query.sh my-project CMy_2efZpKz-VA
#   ./query.sh my-project CMy_2efZpKz-VA 6h 50
#   ./query.sh my-project CMy_2efZpKz-VA 1d 100 web summary

set -euo pipefail

PROJECT="${1:?Usage: $0 PROJECT GROUP_ID [PERIOD] [LIMIT] [SERVICE] [FORMAT]}"
GROUP_ID="${2:?Usage: $0 PROJECT GROUP_ID [PERIOD] [LIMIT] [SERVICE] [FORMAT]}"
PERIOD="${3:-1d}"
LIMIT="${4:-20}"
SERVICE="${5:-}"
FORMAT="${6:-json}"

case "$PERIOD" in
    1h)  API_PERIOD="PERIOD_1_HOUR" ;;
    6h)  API_PERIOD="PERIOD_6_HOURS" ;;
    1d)  API_PERIOD="PERIOD_1_DAY" ;;
    1w)  API_PERIOD="PERIOD_1_WEEK" ;;
    30d) API_PERIOD="PERIOD_30_DAYS" ;;
    *)   echo "Error: PERIOD must be 1h, 6h, 1d, 1w, or 30d" >&2; exit 1 ;;
esac

case "$FORMAT" in
    json|summary) ;;
    *) echo "Error: FORMAT must be json or summary" >&2; exit 1 ;;
esac

TOKEN=$(gcloud auth print-access-token)

ENCODED_GROUP=$(printf '%s' "$GROUP_ID" | python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""))')
QS="groupId=${ENCODED_GROUP}&timeRange.period=${API_PERIOD}&pageSize=${LIMIT}"
if [[ -n "$SERVICE" ]]; then
    ENCODED_SERVICE=$(printf '%s' "$SERVICE" | python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read(), safe=""))')
    QS="${QS}&serviceFilter.service=${ENCODED_SERVICE}"
fi

RESPONSE=$(curl -fsS -H "Authorization: Bearer $TOKEN" \
    "https://clouderrorreporting.googleapis.com/v1beta1/projects/${PROJECT}/events?${QS}")

if [[ "$FORMAT" == "json" ]]; then
    printf '%s\n' "$RESPONSE"
else
    printf '%s' "$RESPONSE" | python3 -c '
import json, sys
data = json.load(sys.stdin)
events = data.get("errorEvents", [])
if not events:
    print("(no events)")
    sys.exit(0)
patterns = {}
for e in events:
    msg = e.get("message", "") or ""
    first = msg.split("\n", 1)[0][:200]
    svc = e.get("serviceContext", {}).get("service", "?")
    ver = e.get("serviceContext", {}).get("version", "?")
    key = first
    bucket = patterns.setdefault(key, {"count": 0, "services": set(), "versions": set(), "first_event": e})
    bucket["count"] += 1
    bucket["services"].add(svc)
    bucket["versions"].add(ver)
print(f"Events returned: {len(events)}  Distinct patterns: {len(patterns)}")
print()
for i, (first, info) in enumerate(sorted(patterns.items(), key=lambda x: -x[1]["count"]), 1):
    services = ",".join(sorted(info["services"]))
    versions = ",".join(sorted(info["versions"]))
    print(f"[{i}] count={info[\"count\"]}  svc={services}  ver={versions}")
    print(f"    {first}")
    print()
'
fi
