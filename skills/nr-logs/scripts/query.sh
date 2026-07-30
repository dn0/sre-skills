#!/bin/bash
# Query New Relic logs via NRQL.
# Usage: ./query.sh [--raw] NRQL [TIMEOUT_SECONDS]
#
#   --raw   Print the raw NRQL results array as JSON (for jq pipelines /
#           saving to a file). Without --raw: prints Data exploration URL,
#           copies NRQL to clipboard, and formats results (markdown table for
#           FACET aggregates, indented JSON otherwise).
#
# Transport: uses the `newrelic` CLI (`newrelic nrql query`) when available,
# otherwise falls back to the NerdGraph GraphQL API via curl+jq. Both paths
# yield the same NRQL results array, so downstream output is identical.
#
# Requires: NEW_RELIC_API_KEY, NEW_RELIC_ACCOUNT_ID; python3; and either the
# `newrelic` CLI (preferred) or curl+jq (fallback).
#
# Note: TIMEOUT_SECONDS sets the NRQL execution timeout and only applies to the
# curl fallback; the `newrelic` CLI has no timeout flag and uses its default.
#
# Examples:
#   ./query.sh "FROM Log SELECT count(*) WHERE level = 'ERROR' SINCE 1 hour ago FACET hostname"
#   ./query.sh "FROM Log SELECT * WHERE labels.app = 'my-app' AND level = 'ERROR' SINCE 30 MINUTES AGO LIMIT 100"
#   ./query.sh --raw "FROM Log SELECT count(*) FACET level SINCE 1 HOUR AGO" > /tmp/nr-logs.json

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

# --- clipboard + UI URL (best-effort, only for human-facing output) ---
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

# --- fetch: prefer the newrelic CLI, fall back to NerdGraph via curl+jq ---
# Both branches set RESULTS to the NRQL results array (JSON).
if command -v newrelic >/dev/null 2>&1; then
  # CLI reads NEW_RELIC_API_KEY from the environment; errors go to stderr and
  # the command exits non-zero, so failures surface without extra handling.
  if ! RESULTS=$(newrelic nrql query \
      --accountId "$NEW_RELIC_ACCOUNT_ID" \
      --format JSON \
      --query "$NRQL"); then
    echo "newrelic CLI query failed (see message above)." >&2
    exit 1
  fi
else
  command -v curl >/dev/null 2>&1 || { echo "Error: need the 'newrelic' CLI or curl." >&2; exit 1; }
  command -v jq   >/dev/null 2>&1 || { echo "Error: curl fallback requires jq." >&2; exit 1; }

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

  RESULTS=$(echo "$RESPONSE" | jq -c '.data.actor.account.nrql.results')
fi

# --- output ---
if [[ "$RAW" == true ]]; then
  echo "$RESULTS"
else
  echo "$RESULTS" | python3 -c '
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
