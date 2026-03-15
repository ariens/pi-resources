#!/usr/bin/env bash
# List failed/broken jobs with triage metadata.
# Usage: bk-failed-jobs.sh <pipeline> <build_number>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/bk-creds.sh"

PIPELINE="${1:?Usage: bk-failed-jobs.sh <pipeline> <build_number>}"
BUILD_NUM="${2:?Usage: bk-failed-jobs.sh <pipeline> <build_number>}"

curl -sf -H "Authorization: Bearer $BK_TOKEN" \
  "$BK_BASE/pipelines/$PIPELINE/builds/$BUILD_NUM?include_retried_jobs=true" | \
  jq '{
    build: {
      number: .number,
      state: .state,
      branch: .branch,
      commit: .commit[0:8],
      web_url: .web_url
    },
    failed: [
      .jobs[]
      | select(.state == "failed")
      | {id, name, state, exit_status, step_key}
    ],
    broken: [
      .jobs[]
      | select(.state == "broken")
      | {id, name, state, exit_status, step_key}
    ],
    running: [
      .jobs[]
      | select(.state == "running")
      | {name, step_key}
    ],
    passed: [
      .jobs[]
      | select(.state == "passed")
      | {name, step_key}
    ],
    triage: {
      total_jobs: (.jobs | length),
      total_failed: ([.jobs[] | select(.state == "failed")] | length),
      total_broken: ([.jobs[] | select(.state == "broken")] | length),
      total_passed: ([.jobs[] | select(.state == "passed")] | length),
      total_running: ([.jobs[] | select(.state == "running")] | length),
      total_canceled: ([.jobs[] | select(.state == "canceled")] | length),
      infra_broken: ([
        .jobs[]
        | select(.state == "broken" or .state == "failed")
        | select(.name // "" | test("docker|setup|bootstrap|cache|bundler|image"; "i"))
      ] | length),
      likely_cascade: (
        ([.jobs[] | select(.state == "broken")] | length) > 10
        and ([.jobs[] | select(.state == "broken") | select(.exit_status == null)] | length) > 5
      )
    }
  }'
