#!/bin/bash
# List New Relic alert policies.
# Usage: ./list-policies.sh [--raw] [SEARCH_NAME]
#
#   --raw   Print the policies array as JSON (for jq pipelines / saving to a
#           file). Without --raw: prints a markdown table of policies.
#
# Transport: uses the `newrelic` CLI (`newrelic nerdgraph query`) when
# available, otherwise falls back to the NerdGraph GraphQL API via curl+jq.
#
# Requires: NEW_RELIC_API_KEY, NEW_RELIC_ACCOUNT_ID; python3; and either the
# `newrelic` CLI (preferred) or curl+jq (fallback).
#
# Examples:
#   ./list-policies.sh                  # List all policies
#   ./list-policies.sh "pagerduty"      # Search by name
#   ./list-policies.sh --raw > /tmp/nr-policies.json

set -euo pipefail

RAW=false
if [[ "${1:-}" == "--raw" ]]; then
  RAW=true
  shift
fi

SEARCH="${1:-}"

: "${NEW_RELIC_API_KEY:?NEW_RELIC_API_KEY environment variable is required}"
: "${NEW_RELIC_ACCOUNT_ID:?NEW_RELIC_ACCOUNT_ID environment variable is required}"

if [[ -n "$SEARCH" ]]; then
  # Escape any embedded double quotes for the GraphQL string literal.
  SAFE_SEARCH=${SEARCH//\"/\\\"}
  CRITERIA="(searchCriteria: { name: \"${SAFE_SEARCH}\" })"
else
  CRITERIA=""
fi
QUERY="{ actor { account(id: ${NEW_RELIC_ACCOUNT_ID}) { alerts { policiesSearch${CRITERIA} { policies { id name incidentPreference } totalCount } } } } }"

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

# --- output ---
echo "$RESPONSE" | RAW="$RAW" python3 -c '
import json, os, sys

raw_mode = os.environ["RAW"] == "true"

resp = json.load(sys.stdin)
acct = (resp.get("data") or resp).get("actor", {}).get("account", {})
search = (acct.get("alerts", {}).get("policiesSearch", {}) or {})
policies = search.get("policies") or []

if raw_mode:
    print(json.dumps(policies, indent=2))
    raise SystemExit

if not policies:
    print("(no policies found)")
    raise SystemExit

def esc(c):
    return str(c).replace("|", "\\|").replace("\n", " ")

headers = ["id", "name", "incidentPreference"]
print("| " + " | ".join(headers) + " |")
print("| " + " | ".join("---" for _ in headers) + " |")
for p in policies:
    row = [p.get("id", ""), p.get("name", ""), p.get("incidentPreference", "")]
    print("| " + " | ".join(esc(c) for c in row) + " |")

total = search.get("totalCount")
shown = len(policies)
suffix = f" of {total}" if total is not None and total != shown else ""
print(f"\n{shown}{suffix} policy(ies).", file=sys.stderr)
'
