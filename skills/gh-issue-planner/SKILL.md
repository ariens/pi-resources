---
name: gh-issue-planner
description: Plan and create GitHub parent issues and sub-issues for investigations, implementations, or deliverable tracking. Creates a parent tracker issue with a delivery plan and individual sub-issues with Slack metadata, dependency graphs, and deliverables. Use when the user asks to plan work, break down a project, create issues, or organize deliverables.
---

# GitHub Issue Planner

Break down a project into a parent tracker issue and sequenced sub-issues. The structure produced by this skill is designed to work with the `pr-review-request-slack-message` skill for automated Slack posting.

## When to Use

- User asks to plan an implementation, investigation, or project
- User wants to break work into trackable deliverables
- User has a problem statement and wants a delivery plan
- User asks to create GitHub issues for a body of work

## Step 1: Understand the Work

Before creating anything, gather enough context to define:

1. **Problem** — What's broken or missing?
2. **Solution** — What's the approach at a high level?
3. **Deliverables** — What are the discrete, mergeable units of work?
4. **Dependencies** — Which deliverables block others?
5. **Slack channels** — Where should PR reviews be posted? Ask the user if not obvious.

Ask the user clarifying questions if any of these are unclear. Do not guess.

## Step 2: Determine the Repository

Ask the user which repository the issues should be created in. Use `gh` CLI for all issue creation:

```bash
gh issue create --repo <owner>/<repo> --title "..." --body "..."
```

## Step 3: Create the Parent Issue

The parent issue is the **tracker** — it provides the big picture, links to all sub-issues, and tracks overall progress.

### Parent Issue Title Format

```
<Project Name>: <Type>
```

Where type is one of: `Implementation`, `Investigation`, `Delivery Tracker`, `Migration`, etc.

### Parent Issue Body Template

Use this structure. All sections are required unless marked optional.

```markdown
# <Project Name>: <Type>

**Feature flag:** `f_flag_name` _(optional — include if work is behind a flag)_
**Last updated:** <date>

---

## Problem

<1–2 paragraphs describing what's broken, missing, or needed. Be specific.>

## Solution

<1–2 paragraphs describing the approach. Include key architectural decisions.>

---

## Delivery Plan

<ASCII dependency graph showing the relationships between steps>

| Step | Issue | Title | Status |
|------|-------|-------|--------|
| 0 | #NNN | <title> | 🔲 Open |
| 1 | #NNN | <title> | 🔲 Open |
| ... | ... | ... | ... |

### Follow-ups (post-launch)

| Issue | Title |
|-------|-------|
| #NNN | <title> |

---

## Key Architecture Decisions

1. **<Decision>** — <Rationale>
2. ...

---

## Scope Boundaries

### In scope
- ...

### Out of scope (tracked as follow-ups)
- ...
```

### Status Icons

| Icon | Meaning |
|------|---------|
| 🔲 | Open — not started |
| 🟡 | In progress / Draft PR |
| ✅ | Done |
| 🚫 | Blocked |

### Dependency Graph

Use ASCII art to show step dependencies. This helps reviewers understand what can be parallelized:

```
#10 Step 0 ──→ #11 Step 1 ──┬──→ #12 Step 2 ──┐
                             │                  │
                             └──→ #13 Step 3 ───┤
                                                │
                                   #14 Step 4 ──→ #15 Step 5
```

## Step 4: Create Sub-Issues

Create one sub-issue per deliverable. Each sub-issue must follow this structure.

### Sub-Issue Title Format

```
Step <N>: <Concise description of the deliverable>
```

### Sub-Issue Body Template

The **top of the body** must contain the Slack metadata block. This is critical — the `pr-review-request-slack-message` skill parses these lines to determine where to post PR reviews.

```markdown
Slack channel: #<primary-channel>
Slack channels for CC: #<cc-channel-1>, #<cc-channel-2>
Slack users to ping: @<handle_1>, @<handle_2>

## Parent Issue
<full URL to parent issue>

## Description

<What this step does and why. Enough context for a reviewer to understand the PR without reading the parent issue.>

## Deliverables

- **<N>.<letter>** <Specific deliverable with file paths or concrete actions>
- **<N>.<letter>** ...

## Prerequisites

- <What must be done before this step can start>

## Blocks

- <What depends on this step being completed>
```

### Slack Metadata Block Rules

The following three lines MUST appear at the very top of every sub-issue body, before any other content:

```
Slack channel: #<channel>
Slack channels for CC: #<channel-1>, #<channel-2>
Slack users to ping: @<handle_1>, @<handle_2>
```

Rules:
- **Slack channel** — Required. The primary channel where PR review requests will be posted.
- **Slack channels for CC** — Optional. Channels that receive an x-post with a link to the primary review request. Omit the line entirely if none.
- **Slack users to ping** — Optional. Slack handles who will be @mentioned on the review request. Omit the line entirely if none.

**Ask the user** for these values when creating issues. Never assume or infer channel names or handles.

If the user provides these values, apply them to ALL sub-issues (they typically share the same Slack metadata). If values differ per sub-issue, the user will specify.

### Deliverables Section

Be specific. Include:
- File paths when known
- Config changes vs. code changes
- What "done" looks like for each item

Bad: `Update the config`
Good: `Add SERVICE_APP_ID = 000000000000 constant to components/platform/essentials/app/models/api_client.rb`

### Prerequisites and Blocks

Every sub-issue should declare:
- **Prerequisites** — Which steps must complete first (reference by step number)
- **Blocks** — Which steps are waiting on this one

This creates a traceable dependency chain. If a sub-issue has no prerequisites, say so: `None — can start immediately`.

## Step 5: Update the Parent Issue

After all sub-issues are created, update the parent issue's delivery plan table with the actual issue numbers:

```bash
gh issue edit <parent-issue-url> --body "<updated body with real issue numbers>"
```

The delivery plan table should reference real issue numbers, not placeholders.

## Step 6: Confirm with the User

Present the full plan to the user:

```
✅ Created parent issue and N sub-issues:

📋 Parent: #<N> — <title>
  ├── #<N> Step 0: <title>
  ├── #<N> Step 1: <title>
  ├── #<N> Step 2: <title>
  └── #<N> Step 3: <title>

Slack metadata applied to all sub-issues:
  📣 Primary: #<channel>
  📋 CC: #<cc-channel-1>, #<cc-channel-2>
  👤 Ping: @<handle_1>, @<handle_2>
```

## Issue Creation Order

Always create issues in this order:

1. **Sub-issues first** (in step order: 0, 1, 2, ...)
2. **Parent issue last** (so it can reference real sub-issue numbers in the delivery plan)

This avoids placeholder issue numbers in the parent.

If a follow-up issue is needed (post-launch work), create it after the sub-issues but before the parent.

## Tips for the Agent

- **Don't create issues without user confirmation.** Present the plan first, then create after approval.
- **One PR per sub-issue.** Each sub-issue should map to exactly one PR. If a step needs multiple PRs, split it into sub-steps (e.g., Step 2a, Step 2b).
- **Keep sub-issue descriptions self-contained.** A reviewer reading only the sub-issue should understand what to review and why.
- **Include enough context in each sub-issue** that someone unfamiliar with the parent issue can review the associated PR.
- **Use `gh issue create`** for creation and `gh issue edit` for updates. Always use `--repo` to be explicit about the target repository.
