#!/usr/bin/env bash
# Get build metadata: state, branch, commit, job counts.
# Usage: bk-build-info.sh <pipeline> <build_number>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/bk-creds.sh"

PIPELINE="${1:?Usage: bk-build-info.sh <pipeline> <build_number>}"
BUILD_NUM="${2:?Usage: bk-build-info.sh <pipeline> <build_number>}"

curl -sf -H "Authorization: Bearer $BK_TOKEN" \
  "$BK_BASE/pipelines/$PIPELINE/builds/$BUILD_NUM" | \
  jq '{
    number,
    state,
    branch,
    commit: .commit[0:8],
    web_url,
    created_at,
    started_at,
    finished_at,
    message: (.message // "" | split("\n")[0] | .[0:120]),
    jobs_total: (.jobs | length),
    jobs_by_state: (
      .jobs
      | group_by(.state)
      | map({state: .[0].state, count: length})
      | sort_by(-.count)
    )
  }'
