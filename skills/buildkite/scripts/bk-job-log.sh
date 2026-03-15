#!/usr/bin/env bash
# Download a job's log to a local file.
# Usage: bk-job-log.sh <pipeline> <build_number> <job_id>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/bk-creds.sh"

PIPELINE="${1:?Usage: bk-job-log.sh <pipeline> <build_number> <job_id>}"
BUILD_NUM="${2:?Usage: bk-job-log.sh <pipeline> <build_number> <job_id>}"
JOB_ID="${3:?Usage: bk-job-log.sh <pipeline> <build_number> <job_id>}"

LOG_DIR="/tmp/buildkite-logs"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/${PIPELINE}-${BUILD_NUM}-${JOB_ID}.log"

# Fetch log content, strip Buildkite timestamp prefixes
curl -sf -H "Authorization: Bearer $BK_TOKEN" \
  "$BK_BASE/pipelines/$PIPELINE/builds/$BUILD_NUM/jobs/$JOB_ID/log" | \
  jq -r '.content // empty' | \
  sed 's/_bk;t=[0-9]*//g' > "$LOG_FILE"

if [[ ! -s "$LOG_FILE" ]]; then
  echo "Error: No log content available for job $JOB_ID" >&2
  rm -f "$LOG_FILE"
  exit 1
fi

LINE_COUNT=$(wc -l < "$LOG_FILE" | tr -d ' ')
echo "Downloaded $LINE_COUNT lines → $LOG_FILE"
