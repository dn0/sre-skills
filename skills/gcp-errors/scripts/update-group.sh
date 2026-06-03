#!/bin/bash
# Update an error group's resolution status and (optionally) attach a tracking issue.
# Usage: ./update-group.sh PROJECT GROUP_ID STATUS [ISSUE_URL]
#
# STATUS: open, acknowledged, resolved, muted (case-insensitive)
# ISSUE_URL: URL to attach as a tracking issue. Replaces any existing tracking
#            issues. Omit to preserve existing ones.
#
# The Error Reporting API has no PATCH/updateMask for groups — only a full PUT.
# To preserve fields we're not changing (notably trackingIssues), we GET the
# current group, mutate it, and PUT it back. This has a small race window if
# two writers update the same group concurrently; fine for human-driven triage.
#
# Examples:
#   ./update-group.sh my-project CMy_2efZpKz-VA acknowledged
#   ./update-group.sh my-project CMy_2efZpKz-VA acknowledged https://github.com/org/repo/issues/42
#   ./update-group.sh my-project CMy_2efZpKz-VA resolved

set -euo pipefail

PROJECT="${1:?Usage: $0 PROJECT GROUP_ID STATUS [ISSUE_URL]}"
GROUP_ID="${2:?Usage: $0 PROJECT GROUP_ID STATUS [ISSUE_URL]}"
STATUS="${3:?Usage: $0 PROJECT GROUP_ID STATUS [ISSUE_URL]}"
ISSUE_URL="${4:-}"

STATUS_UPPER=$(printf '%s' "$STATUS" | tr '[:lower:]' '[:upper:]')
case "$STATUS_UPPER" in
    OPEN|ACKNOWLEDGED|RESOLVED|MUTED) ;;
    *) echo "Error: STATUS must be open, acknowledged, resolved, or muted" >&2; exit 1 ;;
esac

TOKEN=$(gcloud auth print-access-token)
GROUP_URL="https://clouderrorreporting.googleapis.com/v1beta1/projects/${PROJECT}/groups/${GROUP_ID}"

CURRENT=$(curl -fsS -H "Authorization: Bearer $TOKEN" "$GROUP_URL")

BODY=$(printf '%s' "$CURRENT" | STATUS_UPPER="$STATUS_UPPER" ISSUE_URL="$ISSUE_URL" python3 -c '
import json, os, sys
data = json.load(sys.stdin)
data["resolutionStatus"] = os.environ["STATUS_UPPER"]
issue = os.environ["ISSUE_URL"]
if issue:
    data["trackingIssues"] = [{"url": issue}]
print(json.dumps(data))
')

curl -fsS -X PUT \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BODY" \
    "$GROUP_URL"
