#!/bin/bash
# Get full metadata for a single error group from GCP Error Reporting.
# Returns resolutionStatus and trackingIssues — useful before/after update-group.sh.
# Usage: ./get-group.sh PROJECT GROUP_ID
#
# Examples:
#   ./get-group.sh my-project CMy_2efZpKz-VA

set -euo pipefail

PROJECT="${1:?Usage: $0 PROJECT GROUP_ID}"
GROUP_ID="${2:?Usage: $0 PROJECT GROUP_ID}"

TOKEN=$(gcloud auth print-access-token)

curl -fsS -H "Authorization: Bearer $TOKEN" \
    "https://clouderrorreporting.googleapis.com/v1beta1/projects/${PROJECT}/groups/${GROUP_ID}"
