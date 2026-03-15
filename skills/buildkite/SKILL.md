---
name: buildkite
description: Query Buildkite builds, inspect failures, download job logs, and triage CI issues. Use when the user pastes a Buildkite URL, asks about a build status, wants to see failed jobs, or needs to debug CI failures. Supports build info, failed job listing, log download, pipeline search, and failure triage.
---

# Buildkite

Query the Buildkite REST API to inspect builds, triage failures, and download logs.

## Secrets

This skill reads credentials from `~/.pi/secrets.json`:

```json
{
  "buildkite": {
    "token": "bkua_...",
    "org": "your-org"
  }
}
```

Create your token at https://buildkite.com/user/api-access-tokens with scopes: `read_pipelines`, `read_builds`, `read_build_logs`.

## URL Parsing

Buildkite URLs follow this pattern:
```
https://buildkite.com/<org>/<pipeline>/builds/<number>#<job-id>
```

When the user pastes a URL, extract `pipeline`, `build_number`, and optionally `job_id` from it.

## Scripts

All scripts read the token from `~/.pi/secrets.json` automatically.

### Get Build Info

```bash
<skill-dir>/scripts/bk-build-info.sh <pipeline> <build_number>
```

Returns: state, branch, commit, created/started/finished times, job counts by state.

### List Failed Jobs

```bash
<skill-dir>/scripts/bk-failed-jobs.sh <pipeline> <build_number>
```

Returns: all failed and broken jobs with id, name, state, exit_status, step_key. Also includes triage metadata (cascade detection, infra hints).

### Download Job Log

```bash
<skill-dir>/scripts/bk-job-log.sh <pipeline> <build_number> <job_id>
```

Downloads the log to `/tmp/buildkite-logs/<pipeline>-<build_number>-<job_id>.log` and prints the path. Use `read` or `bash grep` to examine the log afterward.

### List Pipelines

```bash
<skill-dir>/scripts/bk-pipelines.sh [search_term] [page]
```

Returns: pipeline slugs, names, URLs. Use to find the correct pipeline slug.

### List Failed Builds

```bash
<skill-dir>/scripts/bk-failed-builds.sh <pipeline> [branch] [page]
```

Returns: recent failed builds for a pipeline.

## Triage Workflow

When investigating a build failure:

1. **Get build info** — check overall state and job counts
2. **List failed jobs** — identify which jobs actually failed vs. broke (cascade)
3. **Detect cascades** — if many jobs are `broken` (exit_status: null) and a setup/docker/infra step failed, it's a cascade. Report this clearly.
4. **Download logs for real failures** — focus on jobs with state `failed` (not `broken`). Download their logs.
5. **Search logs** — use `grep -i "error\|fail\|violation" /tmp/buildkite-logs/<file>` to find root causes
6. **Prioritize** — test failures > module boundary/lint failures > infra failures. Non-infra failures are likely code issues.

### Cascade Detection

A cascade failure is when an upstream job (Docker image build, bundler cache, DB setup) fails, causing all dependent jobs to be marked `broken` with `exit_status: null`. When you see this pattern:
- Report the upstream root cause clearly
- Note how many jobs are broken as a consequence
- Distinguish cascade damage from actual code failures

## Examples

```
"What's the status of https://buildkite.com/my-org/my-pipeline/builds/12345?"
"Show me the failed jobs for build 67890 on my-pipeline-checks"
"Download the log for job abc-123 from that build"
"List recent failed builds on my-pipeline"
"Why did my CI fail?" (look for a Buildkite URL in context)
```
