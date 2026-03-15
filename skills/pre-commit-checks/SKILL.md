---
name: pre-commit-checks
description: "Stub — defines the interface for pre-commit validation. The real implementation lives in your local_skills_dir (never versioned) with system-specific commands and a learnings file. Create your own, then let ci-monitor maintain the learnings through real CI failures."
---

# Pre-Commit Checks (Stub)

This is an **interface definition**, not an executable skill. The real `pre-commit-checks` lives in your local skills directory. Pi should load the local version via symlink, not this stub.

If you're seeing this in Pi, your symlink points to the public repo instead of your local implementation. Fix it:

```bash
LOCAL_DIR=$(python3 -c "import json; d=json.load(open('$HOME/.pi/secrets.json'))['skills']['local_skills_dir']; print(d.replace('~', '$HOME'))")
ln -sf "$LOCAL_DIR/pre-commit-checks" ~/.pi/agent/skills/pre-commit-checks
```

## Setup

### 1. Configure the path

Add to `~/.pi/secrets.json`:

```json
{
  "skills": {
    "local_skills_dir": "~/.pi/local-skills"
  }
}
```

### 2. Create the local skill directory

```bash
mkdir -p ~/.pi/local-skills/pre-commit-checks
```

### 3. Create your SKILL.md

Create `~/.pi/local-skills/pre-commit-checks/SKILL.md` with your system-specific pre-commit procedure. Example skeleton:

```markdown
---
name: pre-commit-checks
description: "BLOCKING: Run before every commit. Validates syntax, regenerates
generated files, checks module boundaries, and runs affected tests."
---

# Pre-Commit Checks

## When to Run
- Before EVERY commit

## Steps

### 1. Syntax Check
\`\`\`bash
git diff --name-only --diff-filter=ACMR | grep '\.rb$' | xargs -I{} ruby -c {}
\`\`\`

### 2. Regenerate Generated Files
<your commands here — e.g., type definition generators, schema compilers>

### 3. Linter/Convention Checks
<your linter commands — reference learnings.md Active Rules>

### 4. Module Boundary Checks
<your boundary checker commands>

### 5. Read and Apply Learnings
Read `learnings.md` in this directory. For each Active Rule that has a
`Check` field, run the check command. Fail if any check fails.

### 6. Run Affected Tests
<your test runner for changed files>

### 7. Report
Report pass/fail. Do NOT allow the commit if any step fails.
```

Customize every step with your real tool paths and commands. This file is never versioned.

### 4. Create learnings.md

Create `~/.pi/local-skills/pre-commit-checks/learnings.md` with this template:

```markdown
# CI Learnings

Living history of what makes CI pass. `ci-monitor` writes entries after every
failure investigation. `pre-commit-checks` reads Active Rules before every commit.

## Active Rules

Rules currently applied during pre-commit checks. Each has a concrete `Check`
command that `pre-commit-checks` can execute to verify compliance.

_(ci-monitor will append entries here)_

## Negative Learnings

Things that look right but cause failures. Do not do these.

_(ci-monitor will append entries here)_

## Retired Rules

Rules that no longer apply. Kept for history, excluded from pre-commit context.

_(move stale Active Rules here during curation)_
```

### 5. Symlink the local version

```bash
ln -sf ~/.pi/local-skills/pre-commit-checks ~/.pi/agent/skills/pre-commit-checks
```

This must point to your **local** directory, not this public stub.

## Learning Entry Format

`ci-monitor` writes entries to `learnings.md` in this format:

**Active Rule:**
```markdown
### <Short title describing the rule>
- **Rule:** <one-sentence imperative: what to always/never do>
- **Check:** `<shell command or grep pattern that verifies compliance>`
- **Example fix:** `<the command or change that resolves the violation>`
- _[learned <YYYY-MM-DD> from <pipeline> #<build_number>]_
```

**Negative Learning:**
```markdown
### <Short title>
- **Rule:** NEVER <do X> — it causes <Y>
- **Check:** `<how to detect if someone did X>`
- _[learned <YYYY-MM-DD> from <pipeline> #<build_number>]_
```

The `Check` field is what makes a learning actionable. Without it, the learning is documentation only. `pre-commit-checks` should execute every `Check` command in Active Rules and fail the commit if any check fails.

## Curation

The user is responsible for periodic curation of `learnings.md`:

- **When to curate:** When `learnings.md` exceeds ~30 Active Rules, or when you notice rules that no longer apply (the codebase changed, the linter rule was removed, the dependency was refactored away).
- **How:** Move the entire rule block (title + bullet points + date) from `Active Rules` to `Retired Rules`. Do not delete — retired rules are historical context.
- **What makes a rule stale:** The `Check` command no longer matches any files in the codebase, or the CI pipeline no longer enforces the underlying rule.
- **Who curates:** The user, not the agent. The agent writes learnings; the user decides when they expire.

## Interface Contract

When the model loads this skill (the local version), it must:

1. Read the local `SKILL.md` and execute all steps
2. Read `learnings.md` — parse Active Rules and Negative Learnings only (skip Retired)
3. For each Active Rule with a `Check` field, execute the check
4. Fail the commit if any step or check fails
5. Report pass/fail summary

If the local skill doesn't exist, warn:

> ⚠️ No local pre-commit-checks found at `<local_skills_dir>/pre-commit-checks/`.
> Create one with your system-specific commands. See the public stub for instructions.
