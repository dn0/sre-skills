#!/bin/bash
# Query New Relic via NRQL using NerdGraph API.
# Usage: ./query.sh [--raw] NRQL [TIMEOUT_SECONDS]
#
#   --raw   Print full NerdGraph JSON (for jq pipelines / saving to file).
#           Without --raw: prints Data exploration URL, copies NRQL to
#           clipboard, and formats results (markdown table for FACET
#           aggregates, indented JSON otherwise).
#
# Requires: NEW_RELIC_API_KEY, NEW_RELIC_ACCOUNT_ID; jq; curl; python3
#
# Examples:
#   ./query.sh "SELECT average(duration) FROM Transaction WHERE appName = 'my-app' SINCE 1 HOUR AGO TIMESERIES"
#   ./query.sh "SELECT sum(restartCountDelta) FROM K8sContainerSample FACET podName SINCE 30 MINUTES AGO"
#   ./query.sh --raw "SELECT count(*) FROM Transaction SINCE 1 HOUR AGO" > /tmp/nr.json

set -euo pipefail

RAW=false
if [[ "${1:-}" == "--raw" ]]; then
  RAW=true
  shift
fi

NRQL="${1:?Usage: $0 [--raw] NRQL [TIMEOUT_SECONDS]}"
TIMEOUT="${2:-30}"

: "${NEW_RELIC_API_KEY:?NEW_RELIC_API_KEY environment variable is required}"
: "${NEW_RELIC_ACCOUNT_ID:?NEW_RELIC_ACCOUNT_ID environment variable is required}"

# --- clipboard (best-effort, stderr) ---
if [[ "$RAW" == false ]]; then
  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$NRQL" | pbcopy
    echo "NRQL copied to clipboard (pbcopy)." >&2
  elif command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$NRQL" | wl-copy
    echo "NRQL copied to clipboard (wl-copy)." >&2
  elif command -v xclip >/dev/null 2>&1; then
    printf '%s' "$NRQL" | xclip -selection clipboard
    echo "NRQL copied to clipboard (xclip)." >&2
  fi

  echo "Data exploration URL: https://one.newrelic.com/data-exploration?account=${NEW_RELIC_ACCOUNT_ID}"
  echo
fi

# --- query ---
PAYLOAD=$(jq -n \
  --argjson accountId "$NEW_RELIC_ACCOUNT_ID" \
  --arg nrql "$NRQL" \
  --argjson timeout "$TIMEOUT" \
  '{
    query: "{ actor { account(id: \($accountId)) { nrql(query: \($nrql | tojson), timeout: \($timeout)) { results } } } }"
  }')

RESPONSE=$(curl -sS -X POST https://api.newrelic.com/graphql \
  -H "Content-Type: application/json" \
  -H "API-Key: ${NEW_RELIC_API_KEY}" \
  -d "$PAYLOAD")

if echo "$RESPONSE" | jq -e '.errors != null and (.errors | length) > 0' >/dev/null 2>&1; then
  echo "$RESPONSE" | jq . >&2
  exit 1
fi

# --- output ---
if [[ "$RAW" == true ]]; then
  echo "$RESPONSE"
else
  echo "$RESPONSE" | jq '.data.actor.account.nrql.results' | python3 -c '
import json, sys

def _facet_cells(facet):
    if facet is None:
        return ["(null)"]
    if isinstance(facet, list):
        return ["(null)" if x is None else str(x) for x in facet] or ["(null)"]
    return [str(facet)]

raw = sys.stdin.read()
try:
    results = json.loads(raw)
except json.JSONDecodeError as e:
    print(f"Invalid JSON: {e}", file=sys.stderr)
    sys.exit(1)

if not isinstance(results, list) or not results:
    print(json.dumps(results, indent=2) if results else "(no results)")
    raise SystemExit

is_facet = all(isinstance(r, dict) and "facet" in r
               and "beginTimeSeconds" not in r for r in results)
if not is_facet:
    print(json.dumps(results, indent=2))
    raise SystemExit

metric_keys = sorted({k for r in results for k in r if k != "facet"})
facet_dim = max((len(_facet_cells(r.get("facet"))) for r in results), default=1)
headers = ([f"facet_{i+1}" for i in range(facet_dim)]
           if facet_dim != 1 else ["facet"])
headers.extend(metric_keys)

def esc(c):
    return c.replace("|", "\\|").replace("\n", " ")

print("| " + " | ".join(headers) + " |")
print("| " + " | ".join("---" for _ in headers) + " |")
for r in results:
    cells = _facet_cells(r.get("facet"))
    cells = (cells + ["(null)"] * facet_dim)[:facet_dim]
    metrics = ["" if r.get(k) is None else str(r.get(k)) for k in metric_keys]
    print("| " + " | ".join(esc(c) for c in cells + metrics) + " |")
'
fi
