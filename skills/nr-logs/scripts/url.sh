#!/bin/bash
# Print the New Relic Data exploration URL + the NRQL to paste in the query console.
# Usage: ./url.sh NRQL
#
# Requires: NEW_RELIC_ACCOUNT_ID environment variable
#
# Why there is no ready-made deep link:
# New Relic's modern "Copy query link" produces a shortened onenr.io URL that
# redirects to .../unified-data-exploration/share?...&state=<UUID>, where the
# query text is stored server-side and referenced by an opaque UUID. That state
# is created by the UI and cannot be constructed offline, so this script cannot
# emit a one-click link with the query embedded. Instead it prints the console
# URL plus the NRQL to paste. (For a shareable link, run once in the UI and use
# "Copy query link".)
#
# Examples:
#   ./url.sh "FROM Log SELECT * WHERE level = 'ERROR' SINCE 30 MINUTES AGO LIMIT 100"
#   ./url.sh "FROM Log SELECT count(*) FACET level SINCE 1 HOUR AGO"

set -euo pipefail

NRQL="${1:?Usage: $0 NRQL}"

: "${NEW_RELIC_ACCOUNT_ID:?NEW_RELIC_ACCOUNT_ID environment variable is required}"

echo "Data exploration URL: https://one.newrelic.com/data-exploration?account=${NEW_RELIC_ACCOUNT_ID}"
echo
echo "$NRQL"

# Best-effort: also copy the NRQL to the clipboard so it is ready to paste.
if command -v pbcopy >/dev/null 2>&1; then
  printf '%s' "$NRQL" | pbcopy
  echo >&2
  echo "NRQL copied to clipboard (pbcopy)." >&2
elif command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "$NRQL" | wl-copy
  echo >&2
  echo "NRQL copied to clipboard (wl-copy)." >&2
elif command -v xclip >/dev/null 2>&1; then
  printf '%s' "$NRQL" | xclip -selection clipboard
  echo >&2
  echo "NRQL copied to clipboard (xclip)." >&2
fi

cat >&2 <<'EOF'

Open the URL above, expand the bottom "Query your data" drawer, choose NRQL,
paste the query, then Run. To share a single link that includes the query,
run it once and click "Copy query link" in the console (this mints a
server-backed onenr.io short link; teammates need New Relic access).
EOF
