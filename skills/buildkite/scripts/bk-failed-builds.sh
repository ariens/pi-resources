#!/usr/bin/env bash
# List recent failed builds for a pipeline.
# Usage: bk-failed-builds.sh <pipeline> [branch] [page]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/bk-creds.sh"

PIPELINE="${1:?Usage: bk-failed-builds.sh <pipeline> [branch] [page]}"
BRANCH="${2:-main}"
PAGE="${3:-1}"

curl -sf -H "Authorization: Bearer $BK_TOKEN" \
  "$BK_BASE/pipelines/$PIPELINE/builds?state=failed&branch=$BRANCH&page=$PAGE&per_page=30" | \
  jq '[.[] | select(.state == "failed") | {number, web_url, branch, state, created_at, started_at, finished_at}]'
