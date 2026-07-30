#!/bin/bash
# Query New Relic alert issues/incidents.
# Usage: ./query.sh [--raw] [STATE] [LIMIT]
#
#   --raw   Print the issues array as JSON (for jq pipelines / saving to a
#           file). Without --raw: prints the Alerts UI URL and a markdown
#           table of issues.
#
#   STATE   open (default), closed, all
#   LIMIT   max issues to show/return (default 50; applied client-side)
#
# Transport: uses the `newrelic` CLI (`newrelic nerdgraph query`) when
# available, otherwise falls back to the NerdGraph GraphQL API via curl+jq.
# Both paths yield the same issues array, so downstream output is identical.
#
# Requires: NEW_RELIC_API_KEY, NEW_RELIC_ACCOUNT_ID; python3; and either the
# `newrelic` CLI (preferred) or curl+jq (fallback).
#
# Examples:
#   ./query.sh open
#   ./query.sh closed 20
#   ./query.sh --raw all 100 > /tmp/nr-issues.json

set -euo pipefail

RAW=false
if [[ "${1:-}" == "--raw" ]]; then
  RAW=true
  shift
fi

STATE="${1:-open}"
LIMIT="${2:-50}"

: "${NEW_RELIC_API_KEY:?NEW_RELIC_API_KEY environment variable is required}"
: "${NEW_RELIC_ACCOUNT_ID:?NEW_RELIC_ACCOUNT_ID environment variable is required}"

case "$STATE" in
  open)   FILTER='filter: { states: ACTIVATED }, ' ;;
  closed) FILTER='filter: { states: CLOSED }, ' ;;
  all)    FILTER='' ;;
  *) echo "Error: STATE must be 'open', 'closed', or 'all'" >&2; exit 1 ;;
esac

FIELDS='issueId title priority state activatedAt closedAt policyName conditionName totalIncidents entityGuids sources origins'
QUERY="{ actor { account(id: ${NEW_RELIC_ACCOUNT_ID}) { aiIssues { issues(${FILTER}cursor: null) { issues { ${FIELDS} } nextCursor } } } } }"

# --- fetch: prefer the newrelic CLI, fall back to NerdGraph via curl+jq ---
if command -v newrelic >/dev/null 2>&1; then
  if ! RESPONSE=$(newrelic nerdgraph query "$QUERY"); then
    echo "newrelic CLI query failed (see message above)." >&2
    exit 1
  fi
else
  command -v curl >/dev/null 2>&1 || { echo "Error: need the 'newrelic' CLI or curl." >&2; exit 1; }
  command -v jq   >/dev/null 2>&1 || { echo "Error: curl fallback requires jq." >&2; exit 1; }

  PAYLOAD=$(jq -n --arg q "$QUERY" '{query: $q}')
  RESPONSE=$(curl -sS -X POST https://api.newrelic.com/graphql \
    -H "Content-Type: application/json" \
    -H "API-Key: ${NEW_RELIC_API_KEY}" \
    -d "$PAYLOAD")
  if echo "$RESPONSE" | jq -e '.errors != null and (.errors | length) > 0' >/dev/null 2>&1; then
    echo "$RESPONSE" | jq . >&2
    exit 1
  fi
fi

# --- output (URL to stdout only in table mode) ---
if [[ "$RAW" == false ]]; then
  echo "Alerts UI URL: https://one.newrelic.com/alerts-ai?account=${NEW_RELIC_ACCOUNT_ID}"
  echo
fi

echo "$RESPONSE" | RAW="$RAW" LIMIT="$LIMIT" STATE="$STATE" python3 -c '
import json, os, sys, datetime

raw_mode = os.environ["RAW"] == "true"
limit = int(os.environ["LIMIT"])
state = os.environ["STATE"]

resp = json.load(sys.stdin)
acct = (resp.get("data") or resp).get("actor", {}).get("account", {})
issues = (acct.get("aiIssues", {}).get("issues", {}) or {}).get("issues") or []
issues = issues[:limit]

if raw_mode:
    print(json.dumps(issues, indent=2))
    raise SystemExit

def flat(v):
    if v is None:
        return ""
    if isinstance(v, list):
        return "; ".join(str(x) for x in v)
    return str(v)

def when(ms):
    if not ms:
        return ""
    return datetime.datetime.utcfromtimestamp(ms / 1000).strftime("%Y-%m-%d %H:%M")

if not issues:
    print(f"(no {state} issues)")
    raise SystemExit

def esc(c):
    return c.replace("|", "\\|").replace("\n", " ")

headers = ["Priority", "State", "Activated", "Incidents", "Title", "Policy"]
print("| " + " | ".join(headers) + " |")
print("| " + " | ".join("---" for _ in headers) + " |")
for it in issues:
    row = [
        flat(it.get("priority")),
        flat(it.get("state")),
        when(it.get("activatedAt")),
        flat(it.get("totalIncidents")),
        flat(it.get("title")),
        flat(it.get("policyName")),
    ]
    print("| " + " | ".join(esc(c) for c in row) + " |")

print(f"\n{len(issues)} {state} issue(s).", file=sys.stderr)
'
