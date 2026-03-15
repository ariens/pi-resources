#!/usr/bin/env bash
# List or search Buildkite pipelines.
# Usage: bk-pipelines.sh [search_term] [page]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/bk-creds.sh"

SEARCH="${1:-}"
PAGE="${2:-1}"

QUERY="page=$PAGE&per_page=20"
if [[ -n "$SEARCH" ]]; then
  QUERY="$QUERY&name=$SEARCH"
fi

curl -sf -H "Authorization: Bearer $BK_TOKEN" \
  "$BK_BASE/pipelines?$QUERY" | \
  jq '[.[] | {slug, name, web_url, default_branch, running_builds_count, scheduled_builds_count}]'
