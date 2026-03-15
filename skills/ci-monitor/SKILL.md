---
name: ci-monitor
description: "Monitor a Graphite PR stack through CI until all PRs are green. Diagnoses failures, fixes trivial issues, writes learnings to prevent recurrence, keeps GitHub issues current, and escalates non-trivial problems. Use when a stack has been submitted and needs to be shepherded to green CI."
---

# CI Monitor

Monitor a submitted Graphite PR stack, fix trivial CI failures, and escalate non-trivial ones.

## Dispatching as a Background Subagent

This skill can run as a background subagent using the `ci-monitor` agent definition
(`~/.pi/agent/agents/ci-monitor.md`). This frees the main session for other work.

```json
{
  "agent": "ci-monitor",
  "task": "Monitor PRs #XXXXX, #XXXXX, #XXXXX in <owner>/<repo>. Repo checkout: /path/to/checkout. Parent issue: <url>. Poll until all green or failure needs escalation.",
  "cwd": "/path/to/checkout"
}
```

The agent has `tools: bash, read, write, edit` — it can run `gh pr checks`, `sleep`,
read Buildkite logs, and make trivial fixes. Do NOT use reviewer agents (`review-*`)
for CI monitoring — they only have read-only tools and cannot execute shell commands.

## Inputs

- A list of PR numbers in stack order (bottom to top)
- The parent GitHub issue URL
- The repo (from user context)
- The local checkout path (from user context)

## Procedure

### 1. Initial Status Check

For each PR, run:

```bash
gh pr checks <pr_number> --repo <repo> 2>&1
```

Categorize each PR as: ✅ green, 🟡 pending, ❌ failed.

### 2. Monitor Loop

Poll every 5 minutes until all PRs are green or a non-trivial failure is found.

```bash
sleep 300
# then re-check all PRs
```

### 3. On Failure — Identify the Source

`gh pr checks` returns **all** check runs — CI pipelines, GitHub Actions, review bots, status checks. Before diagnosing, identify **what kind of check failed**:

```bash
gh pr checks <pr_number> --repo <repo> --json name,state,link 2>&1
```

#### 3a. Triage by Check Source

| Check type | How to identify | Action |
|------------|----------------|--------|
| **CI pipeline** (Buildkite, etc.) | URL contains `buildkite.com` or the check name matches a known pipeline | Use the `buildkite` skill to diagnose: `bk-failed-jobs.sh <pipeline> <build_number>` |
| **AI review bot** | Check name contains "Review Bot", "Comments Addressed", or similar | Fetch the unresolved review comments: `gh api "repos/<repo>/pulls/<pr>/comments"` and filter by the bot's login |
| **GitHub Action** | URL contains `github.com/.../actions/runs` | Read the action logs: `gh run view <run_id> --repo <repo> --log-failed` |
| **Other status check** | None of the above | Read the details URL, report to user |

**Do NOT skip non-pipeline checks.** A PR is not green until ALL checks pass — including review bots, code scanning, and status checks. Checking only Buildkite and reporting "green" when a review bot is blocking is a critical failure mode.

#### 3b. For AI Review Bot Failures

Fetch the unresolved comments:

```bash
gh api "repos/<repo>/pulls/<pr>/comments" \
  --jq '[.[] | select(.user.type == "Bot") | {path: .path, line: .line, body: .body[0:500], author: .user.login}]'
```

These are almost always **non-trivial** — they are code review concerns about logic, security, or correctness. **Escalate to the user** with the comment details. Do not attempt to resolve review bot comments autonomously unless the user explicitly asks.

#### 3c. For CI Pipeline Failures

Use the Buildkite skill to diagnose:

```bash
<buildkite-skill-dir>/scripts/bk-failed-jobs.sh <pipeline> <build_number>
```

#### 3d. Classify the CI Failure

**Trivial (fix autonomously):** These are mechanical failures the agent can fix without changing production logic. The specific categories are defined in your **local** `pre-commit-checks` skill and `learnings.md`. Common examples include:
- Generated type definitions out of date
- Linter/convention violations
- Module boundary violations (missing dependency declarations)
- Test assertion mismatches from renamed methods/error strings
- Missing configuration entries (feature flags, fixtures)

**Non-trivial (STOP and escalate to user):**
- Actual test logic failures in code you wrote
- Failures in tests you didn't touch (possible regression)
- Architectural issues (wrong package dependency, circular reference)
- Failures that require changing the approach described in the GitHub issue
- Any failure you've already tried to fix once and it came back differently
- **Any fix that changes production code logic** — adding rescue clauses, changing control flow, modifying method signatures, or altering return values. Even if the root cause is a test environment artifact (e.g., blanket flag stubs causing unexpected code paths), the fix touches production code and must be reviewed by the user. Escalate, don't fix autonomously.

### 4. On Failure — Fix

1. **Checkout the correct branch** — the branch that owns the failing file. Use `gt checkout <branch>`.
2. **Make the fix.**
3. **Run pre-commit-checks** — read the local skill from `local_skills_dir/pre-commit-checks/SKILL.md` (path from `~/.pi/secrets.json` → `skills.local_skills_dir`). Also read `learnings.md` and apply all Active Rules. Do NOT commit without all checks passing.
4. **Commit** — `gt modify -a -m "<existing commit message>"` (preserve the existing message, or append a note about the fix).
5. **Push the stack** — `gt submit --stack`
6. **Write the learning** — Append a new entry to `local_skills_dir/pre-commit-checks/learnings.md`. See [Learning Format](#learning-format) below. Write to `learnings.md` only — do NOT modify the local `SKILL.md` (the user curates that).
7. **Return to the monitor loop.**

### Learning Format

Every learning written to `learnings.md` must follow this structure so `pre-commit-checks` can read it reliably:

```markdown
### <Short title describing the rule>
- **Rule:** <one-sentence imperative: what to always/never do>
- **Check:** `<shell command or grep pattern that verifies compliance>`
- **Example fix:** `<the command or change that resolves the violation>`
- _[learned <YYYY-MM-DD> from <pipeline> #<build_number>]_
```

For negative learnings, use the same format but the rule starts with "NEVER" or "Do not":

```markdown
### <Short title>
- **Rule:** NEVER <do X> — it causes <Y>
- **Check:** `<how to detect if someone did X>`
- _[learned <YYYY-MM-DD> from <pipeline> #<build_number>]_
```

The `Check` field is critical — it gives `pre-commit-checks` a concrete, executable way to verify the rule. Without it, the learning is just documentation.

### 5. Flailing Detection

Track fixes per PR. If any of these conditions are met, **STOP and escalate**:

- Same CI pipeline fails 3+ consecutive cycles on the same PR
- A fix introduces a new, different failure
- Total fix count across the stack exceeds 5 in one monitoring session
- You're unsure whether a change is within the scope described in the PR's linked GitHub issue

When escalating, report:
- Which PR and pipeline
- The failure log excerpt
- What you've already tried
- Why you think it's non-trivial

### 6. On All Green

When every PR in the stack has all CI checks passing:

1. **Update the parent GitHub issue** — change status for each step to reflect CI results
2. **Report to the user:**

```
✅ Stack is green across all PRs:
- PR #XXXXX (Step N): all checks passed
- PR #XXXXX (Step N): all checks passed

Fixes applied during monitoring:
- <description of fix 1>
- <description of fix 2>

Learnings written: N new rules in learnings.md
```

### 7. Scope Guard

Every fix must be traceable to a deliverable in the linked sub-issue. Before making any fix, verify:

- Is this file part of the PR's changeset?
- Does the fix change behavior, or just satisfy a convention/lint rule?
- Would the fix be surprising to the PR author?

If the answer to the last question is "yes," escalate instead of fixing.

### 8. Sync Skills to Personal Repo

When an **existing** public skill is updated, sync it to the personal repo. **Only update skills already tracked in the public repo.** Never add new skill directories without explicit user confirmation.

```bash
SKILLS_SRC=$(python3 -c "import json; print(json.load(open('$HOME/.pi/secrets.json'))['skills']['source_dir'])")
SKILLS_DEST=$(python3 -c "import json; print(json.load(open('$HOME/.pi/secrets.json'))['skills']['personal_repo_dir'])")

SKILLS_SRC="${SKILLS_SRC/#\~/$HOME}"
SKILLS_DEST="${SKILLS_DEST/#\~/$HOME}"
REPO_ROOT="$(dirname "$SKILLS_DEST")"

# ONLY update skills already tracked on remote — never add new ones
cd "$REPO_ROOT"
TRACKED=$(git ls-tree --name-only origin/main skills/ | sed 's|skills/||')

for skill in $TRACKED; do
  if [ -d "$SKILLS_SRC/$skill" ]; then
    cp -r "$SKILLS_SRC/$skill/"* "$SKILLS_DEST/$skill/"
  fi
done

# Follow the project-local pre-push security gate (.pi/skills/pre-push-security-gate/SKILL.md)
git add skills/ README.md
git commit -m "<description of skill changes>"
git push origin main
```

This must happen:
- After every learnings update that was triggered by a public skill change
- Before reporting "all green" to the user

Note: `learnings.md` lives in `local_skills_dir`, NOT in the public repo. It is never synced.

## Dependencies

- **Buildkite skill** — for failure diagnosis and log download
- **Pre-commit checks** — local-only, at `local_skills_dir/pre-commit-checks/`. ci-monitor reads the SKILL.md and learnings.md, and writes new learnings. Does NOT modify the SKILL.md.
- **Personal skills repo** — path from `~/.pi/secrets.json` under `skills.personal_repo_dir`. Follows the local pre-push gate.
- **GitHub CLI** — `gh pr checks`, `gh issue edit`
- **Graphite CLI** — `gt checkout`, `gt modify`, `gt submit --stack`
