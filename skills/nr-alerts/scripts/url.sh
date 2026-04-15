#!/bin/bash
# Generate New Relic Alerts UI URL
# Usage: ./url.sh [TYPE] [ID]
#
# TYPE: overview (default), issue, policy, condition
#
# Requires: NEW_RELIC_ACCOUNT_ID environment variable
#
# Examples:
#   ./url.sh                                       # Alerts overview
#   ./url.sh issue abc123-def456                    # Specific issue
#   ./url.sh policy 12345                           # Specific policy
#   ./url.sh condition 67890                        # Specific condition

set -euo pipefail

TYPE="${1:-overview}"
ID="${2:-}"

: "${NEW_RELIC_ACCOUNT_ID:?NEW_RELIC_ACCOUNT_ID environment variable is required}"

case "$TYPE" in
    overview)
        echo "https://one.newrelic.com/alerts-ai?account=${NEW_RELIC_ACCOUNT_ID}"
        ;;
    issue)
        if [[ -z "$ID" ]]; then
            echo "Error: issue ID required" >&2
            exit 1
        fi
        echo "https://one.newrelic.com/alerts-ai/issues/${ID}?account=${NEW_RELIC_ACCOUNT_ID}"
        ;;
    policy)
        if [[ -z "$ID" ]]; then
            echo "Error: policy ID required" >&2
            exit 1
        fi
        echo "https://one.newrelic.com/alerts-ai/condition-builder/policy-entity?account=${NEW_RELIC_ACCOUNT_ID}&policyId=${ID}"
        ;;
    condition)
        if [[ -z "$ID" ]]; then
            echo "Error: condition ID required" >&2
            exit 1
        fi
        echo "https://one.newrelic.com/alerts-ai/condition-builder/condition/${ID}?account=${NEW_RELIC_ACCOUNT_ID}"
        ;;
    *)
        echo "Error: TYPE must be 'overview', 'issue', 'policy', or 'condition'" >&2
        exit 1
        ;;
esac
