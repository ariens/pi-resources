# Pi Resources

> **⚠️ SECURITY NOTICE**
>
> This is a **public personal repo**. It must **never** contain secrets, tokens, API keys, internal URLs, or any data related to the projects you work on. All credentials are loaded at runtime from `~/.pi/secrets.json` which is local-only and git-ignored everywhere.
>
> **Two-layer protection:**
> 1. The [`security`](#security) skill provides the scanner (public, in this repo)
> 2. A **project-local pre-push gate** (gitignored, never pushed) enforces the scan before every push and blocks unapproved new skills
>
> See [Setup → Local Pre-Push Security Gate](#local-pre-push-security-gate) to create your local gate.

## Ethos

You think. I deliver.

These skills encode a division of labor between a human and an autonomous coding agent. The human is the cognitive problem solver — they decide what to build, how to architect it, which trade-offs to accept, and when something is wrong. The agent is contractually obligated to handle delivery — the mechanical, repeatable, detail-oriented execution that turns decisions into shipped code.

This means:
- **Planning** is collaborative. `gh-issue-planner` helps the human break down work, but the human decides the decomposition.
- **Execution** is delegated. Once a plan exists, the agent owns the commit loop: pre-commit checks, CI monitoring, failure triage, fix-and-retry, and review posting.
- **Learning** is continuous. Every CI failure the agent encounters becomes a learning that prevents future failures. The human curates; the agent accumulates.
- **Judgment** stays human. The agent escalates when it's unsure, when a fix would surprise the author, or when it's flailing. It never silently changes production logic.

The skills in this repo are the contract. They define what the agent can do autonomously, when it must stop and ask, and how the feedback loop between investigation and prevention works.

---

## Skills

| Skill | Description | Updated |
|-------|-------------|---------|
| [`security`](skills/security/SKILL.md) | 🔒 Scans for secrets, tokens, and company-sensitive data. Provides the scanner used by the local pre-push gate. | 2026-03-13 |
| [`buildkite`](skills/buildkite/SKILL.md) | Query Buildkite builds, inspect failures, download job logs, and triage CI issues. | 2026-03-13 |
| [`ci-monitor`](skills/ci-monitor/SKILL.md) | Monitor a Graphite PR stack through CI until all PRs are green. | 2026-03-13 |
| [`gh-issue-planner`](skills/gh-issue-planner/SKILL.md) | Plan and create GitHub parent issues and sub-issues for multi-step projects. | 2026-03-13 |
| [`pr-review-request-slack-message`](skills/pr-review-request-slack-message/SKILL.md) | Generate and post Slack PR review request messages with preview → confirm → post. | 2026-03-13 |
| [`pre-commit-checks`](skills/pre-commit-checks/SKILL.md) | _(stub)_ Interface definition for pre-commit validation. Includes setup instructions, learnings template, and entry format. Real implementation is local-only. | 2026-03-13 |
| [`submit-stack`](skills/submit-stack/SKILL.md) | 🚦 **Hard gate** before every `gt submit` / `git push`. Runs `pre-commit-checks` (local) + safety checks on all changed files, blocks submit until all pass. The agent must never push without this. | 2026-03-15 |
| [`repo-readme-sync`](skills/repo-readme-sync/SKILL.md) | Sync existing skill updates to this repo and regenerate the README. New skills require manual approval. | 2026-03-13 |

---

### `security`

🔒 The scanner that detects secrets, tokens, internal URLs, and company-sensitive data. This is the **tool**; the **enforcement** lives in the project-local pre-push gate (gitignored).

- Scans all repo files for token patterns (Buildkite, Slack, GitHub, AWS, Bearer, private keys)
- Detects internal URLs loaded from config (no patterns hardcoded in the script)
- Fingerprints every string value in `~/.pi/secrets.json` and scans for verbatim matches
- Detects references to internal GitHub org repos and company name/domains
- All patterns loaded from `~/.pi/secrets.json` at runtime — the script itself contains zero sensitive data

**Scripts:**

| Script | Purpose |
|--------|---------|
| [`scan-secrets.sh`](skills/security/scripts/scan-secrets.sh) | Scan a directory for secrets and sensitive data. Exit 0 = clean, exit 1 = findings. |

---

### `buildkite`

Query the Buildkite REST API to inspect builds, triage failures, and download logs.

- Parses Buildkite URLs to extract pipeline, build number, and job ID
- Fetches build metadata — state, branch, commit, job counts by state
- Lists failed and broken jobs with cascade detection and infra hints
- Downloads job logs to `/tmp/buildkite-logs/` with timestamp prefixes stripped
- Searches pipelines and lists recent failed builds
- Guides the model through a structured triage workflow

**Scripts:**

| Script | Purpose |
|--------|---------|
| [`bk-creds.sh`](skills/buildkite/scripts/bk-creds.sh) | Shared credential loader |
| [`bk-build-info.sh`](skills/buildkite/scripts/bk-build-info.sh) | Build state, branch, commit, job counts |
| [`bk-failed-jobs.sh`](skills/buildkite/scripts/bk-failed-jobs.sh) | Failed/broken jobs + cascade detection |
| [`bk-job-log.sh`](skills/buildkite/scripts/bk-job-log.sh) | Download job log to local file |
| [`bk-pipelines.sh`](skills/buildkite/scripts/bk-pipelines.sh) | Search/list pipelines |
| [`bk-failed-builds.sh`](skills/buildkite/scripts/bk-failed-builds.sh) | Recent failed builds for a pipeline |

---

### `ci-monitor`

Monitor a submitted Graphite PR stack, fix trivial CI failures, and escalate non-trivial ones.

- Polls `gh pr checks` every 5 minutes until **all** checks pass — CI pipelines, review bots, GitHub Actions, status checks
- Triages failures by source: CI pipeline → `buildkite` skill; AI review bot → fetch comments and escalate; GitHub Action → read failed logs
- Classifies CI pipeline failures as trivial or non-trivial (categories defined in your local `pre-commit-checks` and `learnings.md`)
- Fixes trivial issues autonomously, running `pre-commit-checks` (local) before every commit
- **Writes learnings** to `local_skills_dir/pre-commit-checks/learnings.md` after every fix — each with a concrete `Check` command so it's mechanically enforceable
- Writes to `learnings.md` only — does NOT modify the local `SKILL.md` (the user curates that)
- Only syncs updates to skills **already tracked** in this repo — never adds new skill directories
- Follows the project-local pre-push gate before pushing any updates
- Flailing detection: stops and escalates after 3 consecutive failures or 5 total fixes

**Dependencies:** `buildkite`, `pre-commit-checks` (local) · Follows local pre-push gate (which uses `security`)

---

### `gh-issue-planner`

Plan and create GitHub parent issues and sub-issues for multi-step projects.

- Breaks down a project into a parent tracker issue and sequenced sub-issues
- Creates sub-issues first (for real issue numbers), then the parent issue
- Annotates every sub-issue with Slack metadata at the top of the body
- Produces a parent issue with problem/solution, ASCII dependency graph, delivery plan table, architecture decisions, and scope boundaries

**Dependencies:** `pr-review-request-slack-message` (sub-issues created in compatible format)

---

### `pr-review-request-slack-message`

Generate and post Slack PR review request messages with a full preview → confirm → post workflow.

- Fetches a GitHub sub-issue via `gh` CLI to gather context (title, parent issue, step N/total)
- Parses Slack metadata from the issue body (`Slack channel:`, `Slack channels for CC:`, `Slack users to ping:`)
- Validates all Slack channels and resolves user handles to IDs — aborts with full error report if any fail
- Composes a formatted review request message and copies it to the clipboard
- Sends a 3-message DM preview (primary message, CC plan, x-post preview)
- On user confirmation: posts to the primary channel, then x-posts to CC channels with link unfurling

**Scripts:**

| Script | Purpose |
|--------|---------|
| [`slack-creds.sh`](skills/pr-review-request-slack-message/scripts/slack-creds.sh) | Shared credential loader |
| [`slack-post.sh`](skills/pr-review-request-slack-message/scripts/slack-post.sh) | Post a message to Slack |
| [`slack-validate-channel.sh`](skills/pr-review-request-slack-message/scripts/slack-validate-channel.sh) | Validate a Slack channel exists |
| [`slack-resolve-handle.sh`](skills/pr-review-request-slack-message/scripts/slack-resolve-handle.sh) | Resolve `@handle` → Slack user ID |

---

### `pre-commit-checks`

_(Stub — the real implementation is local-only.)_

Mandatory pre-commit validation before every commit. The public skill in this repo defines the **interface** — what the skill should do, how `ci-monitor` interacts with it, and the exact format for learnings entries. The **implementation** lives in your `local_skills_dir` because it contains system-specific commands, tool paths, and class hierarchies related to the project you work on.

**Local structure:**

```
<local_skills_dir>/pre-commit-checks/
├── SKILL.md          ← real skill with system-specific commands
└── learnings.md      ← living history of CI failure learnings
```

**`learnings.md`** is the institutional memory of what makes CI pass:

- **Active Rules** — applied during every pre-commit check. Each has a `Check` command that can be executed mechanically, plus the date and build that taught it.
- **Negative Learnings** — things that look right but cause failures. Also have `Check` commands.
- **Retired Rules** — no longer apply, kept for history, excluded from context to bound token consumption.

**The learning loop:** `ci-monitor` writes learnings (with concrete `Check` commands). `pre-commit-checks` reads Active Rules and executes every `Check`. The user curates — moving stale rules to Retired when the `Check` no longer matches the codebase or the CI rule was removed.

**Curation criteria:** A rule is stale when its `Check` command no longer matches any files, or the CI pipeline no longer enforces the underlying rule. Curate when Active Rules exceed ~30 entries.

See the [stub skill](skills/pre-commit-checks/SKILL.md) for full setup instructions, SKILL.md skeleton, learnings template, and entry format.

---

### `submit-stack`

🚦 **Hard gate before every `gt submit` / `git push`.** The agent must never push code without going through this skill.

- Identifies all changed files in the stack (diff against stack base or `origin/main`)
- Runs the full local `pre-commit-checks` skill — every step, every Active Rule from `learnings.md`
- Safety verification: no debug artifacts, no untracked generated files, clean commit messages
- **Blocks submit until all checks pass.** On failure, reports what failed and what to fix.
- Only after all gates pass does it execute `gt submit --stack`

This skill exists because `pre-commit-checks` is an instruction to the agent, but instructions can drift out of focus in long sessions. `submit-stack` wraps the submit command itself — making the gate unavoidable. The agent cannot reach `gt submit` without going through validation first.

**Dependencies:** `pre-commit-checks` (local) · `~/.pi/secrets.json` for path resolution

---

### `repo-readme-sync`

Sync skill updates to this public repo and regenerate the README.

- **Only updates skills already tracked on `origin/main`** — never adds new skill directories without explicit user confirmation
- Verifies **bidirectional consistency** between the README and every skill's SKILL.md
- Scans `skills/*/SKILL.md` for names, descriptions, and last-updated dates
- Follows the project-local pre-push gate before committing or pushing

**Dependencies:** Follows local pre-push gate (which uses `security`)

---

## Adding New Skills

New skill directories are **never added automatically**. Both `ci-monitor` and `repo-readme-sync` will only update skills that already exist on `origin/main`.

To add a new skill:

1. The model proposes the new skill and **stops to ask for your confirmation**
2. You review the skill content for anything that shouldn't be public
3. You explicitly approve the addition
4. The local pre-push gate runs the security scanner on the new files
5. Only then is it committed and pushed

---

## Integration Map

```
              ┌───────────────────────────────────────┐
              │  LOCAL pre-push security gate          │
              │  (.pi/ — gitignored, never pushed)     │
              │                                        │
              │  1. Runs security scanner              │
              │  2. Audits staged diff                 │
              │  3. Blocks unapproved new skills       │
              └────────────────┬───────────────────────┘
                               │ calls
                               ▼
                         ┌──────────┐
                         │ security │  (public scanner)
                         └──────────┘

   ╔══════════════════════════════════════════════════════╗
   ║ Skills that push to the public repo follow the      ║
   ║ LOCAL pre-push gate (which calls security).         ║
   ║ They do NOT call security directly.                 ║
   ╚══════════════════════════════════════════════════════╝

        ┌────────────┐          ┌───────────┐
        │ ci-monitor │          │ repo-     │
        │            │          │ readme-   │
        └──┬───┬─────┘          │ sync      │
           │   │                └───────────┘
     ┌─────┘   └──────────────────┐
     ▼                            ▼
┌───────────┐  ┌─────────────────────────────────────────┐
│ buildkite │  │ pre-commit-checks (LOCAL, never pushed)  │
│           │  │  ├── SKILL.md (system-specific commands)  │
│           │  │  └── learnings.md (CI failure memory)     │
└───────────┘  └─────────────────────────────────────────┘
                      ▲ writes learnings    │ reads + runs
                      │ (with Check cmds)   │ Check cmds
                      └─── ci-monitor ──────┘

gh-issue-planner ──creates issues──▶ pr-review-request-slack-message
                                      (reads Slack metadata from issue body)
```

**The learning loop:**

```
CI fails
  → ci-monitor diagnoses via buildkite
  → ci-monitor fixes the code
  → ci-monitor writes learning to learnings.md
  → ci-monitor updates local pre-commit-checks if needed
  → next commit: pre-commit-checks reads learnings, applies rules
  → CI passes (or: new failure → new learning → loop)

Periodically:
  → user reviews learnings.md
  → stale rules: Active → Retired
  → context consumption stays bounded
```

**Workflow — full lifecycle of a PR stack:**

1. `gh-issue-planner` — break down the project into tracked sub-issues
2. _(develop code)_
3. `pre-commit-checks` _(local)_ — validate before every commit, applying all active learnings
4. **`submit-stack`** — **hard gate** before pushing: runs `pre-commit-checks` (local) + safety checks on all files in the stack, blocks submit until all pass. The agent must never run `gt submit` or `git push` without going through this gate.
5. `ci-monitor` — monitor CI after submitting the stack
   - diagnoses failures via `buildkite`
   - runs `pre-commit-checks` (local) before fix commits
   - writes learnings to `learnings.md` after every fix
   - follows local pre-push gate before syncing public skill updates
6. `pr-review-request-slack-message` — post review requests to Slack

---

## Setup

### Prerequisites

- [Pi](https://github.com/badlogic/pi) coding agent
- `python3`, `curl`, `jq` on PATH
- `gh` CLI (authenticated)
- `gt` ([Graphite](https://graphite.dev/) CLI) for stack operations
- macOS (`pbcopy` for clipboard)

### 1. Install Public Skills

From the repo root, symlink public skills into your Pi skills directory:

```bash
cd /path/to/pi-resources   # ← must be in the repo root for $(pwd) to work
for skill in skills/*/; do
  name=$(basename "$skill")
  ln -sf "$(pwd)/$skill" ~/.pi/agent/skills/"$name"
done
```

### 2. Create Local Skills

System-specific skills that contain project-related commands, tool paths, and CI learnings live in a **local directory that is never versioned**.

Configure the path in `~/.pi/secrets.json`:

```json
{
  "skills": {
    "local_skills_dir": "~/.pi/local-skills"
  }
}
```

Create the local `pre-commit-checks` — see the [stub skill](skills/pre-commit-checks/SKILL.md) for the full SKILL.md skeleton, learnings.md template, and entry format:

```bash
mkdir -p ~/.pi/local-skills/pre-commit-checks
# Then create SKILL.md and learnings.md per the stub's instructions
```

### 3. Override the Stub Symlink

Step 1 linked the public stub for `pre-commit-checks`. Now **replace** it with your local implementation:

```bash
ln -sf ~/.pi/local-skills/pre-commit-checks ~/.pi/agent/skills/pre-commit-checks
```

This ensures Pi loads your real pre-commit commands, not the interface stub. Do this **after** creating the local SKILL.md and learnings.md in step 2.

### Local Pre-Push Security Gate

This repo uses a **project-local skill** (gitignored, never pushed) to enforce the security scan before every push. Create it:

```bash
mkdir -p .pi/skills/pre-push-security-gate
```

Then create `.pi/skills/pre-push-security-gate/SKILL.md` with instructions that:

1. Run `skills/security/scripts/scan-secrets.sh` against the repo root
2. Audit the staged diff (`git diff --cached`) for secrets, internal URLs, and company references
3. Block any **new** skill directories from being committed without your explicit confirmation
4. Only after all checks pass, allow the push

The `.pi/` directory is in `.gitignore` — it never leaves your machine.

### Configure Secrets

Create `~/.pi/secrets.json` (`chmod 600`) with all credentials:

```json
{
  "company": {
    "name": "Your Company",
    "domains": ["yourco.com", "yourco.io"],
    "orgs": ["yourco", "yourco-internal"],
    "internal_url_patterns": ["vault.yourco.io", "internal.yourco.com"]
  },
  "buildkite": {
    "token": "bkua_...",
    "org": "your-org"
  },
  "slack": {
    "token": "xoxc-...",
    "cookie": "xoxd-...",
    "user_id": "WXXXXXXXX",
    "dm_channel": "DXXXXXXXX",
    "workspace_url": "https://your-workspace.slack.com"
  },
  "skills": {
    "source_dir": "~/.pi/agent/skills",
    "personal_repo_dir": "~/src/github.com/you/pi-resources/skills",
    "local_skills_dir": "~/.pi/local-skills"
  }
}
```

| Key | Used by | Purpose |
|-----|---------|---------|
| `company.*` | `security` | Company name, domains, orgs, internal URLs for secret scanning |
| `buildkite.token` | `buildkite` | API token ([create here](https://buildkite.com/user/api-access-tokens) with `read_pipelines`, `read_builds`, `read_build_logs`) |
| `buildkite.org` | `buildkite` | Buildkite org slug |
| `slack.token` | `pr-review-request-slack-message` | Slack session token (see below) |
| `slack.cookie` | `pr-review-request-slack-message` | Slack session cookie (see below) |
| `slack.user_id` | `pr-review-request-slack-message` | Your Slack user ID (see below) |
| `slack.dm_channel` | `pr-review-request-slack-message` | Your self-DM channel ID (see below) |
| `skills.source_dir` | `ci-monitor` | Where Pi loads skills from |
| `skills.personal_repo_dir` | `ci-monitor`, `repo-readme-sync` | Public repo for syncing skill updates |
| `skills.local_skills_dir` | `ci-monitor`, `pre-commit-checks` | Local-only skills with system-specific commands and learnings |

#### Obtaining Slack Credentials

The `pr-review-request-slack-message` skill uses Slack **session credentials** (not standard OAuth/bot tokens). These are extracted from your browser's authenticated Slack session:

1. **Open Slack in your browser** and sign in
2. **Open DevTools** (F12 or Cmd+Option+I)
3. **`token`** — Go to the Console tab and run: `JSON.parse(localStorage.localConfig_v2).teams[Object.keys(JSON.parse(localStorage.localConfig_v2).teams)[0]].token` — this gives you the `xoxc-` token
4. **`cookie`** — Go to Application → Cookies → `https://app.slack.com` → find the `d` cookie. The value starts with `xoxd-`
5. **`user_id`** — In DevTools Console: `JSON.parse(localStorage.localConfig_v2).teams[Object.keys(JSON.parse(localStorage.localConfig_v2).teams)[0]].user_id`
6. **`dm_channel`** — Open your self-DM in Slack, the URL contains the channel ID (starts with `D`)

⚠️ These are session-based credentials that may expire. If the Slack skill stops working, re-extract them. Never commit these values — they belong in `~/.pi/secrets.json` only.
