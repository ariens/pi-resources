---
name: submit-stack
description: "BLOCKING GATE: This skill MUST be invoked before every gt submit / git push. It runs pre-commit-checks (local) on every commit in the stack, validates all checks pass, and only then submits. The agent must NEVER run gt submit or git push without going through this gate. If you find yourself about to submit, stop and invoke this skill first."
user_invocable: true
---

# Submit Stack

**Hard gate before every submit.** This skill ensures `pre-commit-checks` (local) runs
on all changed files before any code is pushed. The agent must never bypass this.

## When This Skill Applies

This skill is a prerequisite for **any** of these commands:

- `gt submit` / `gt submit --stack`
- `git push`
- `gt modify -a` followed by `gt submit`
- Any workflow that sends commits to a remote

If the agent is about to run any of these, it must execute this skill first.

## Procedure

### Step 1: Identify All Changed Files in the Stack

Determine what's being submitted:

```bash
# For a Graphite stack: diff against the stack base
gt log --short  # see the stack
git diff --name-only $(gt base)..HEAD
```

If `gt` is not available:
```bash
git diff --name-only origin/main..HEAD
```

### Step 2: Run Pre-Commit Checks (Local)

Read the local `pre-commit-checks` skill from `local_skills_dir/pre-commit-checks/SKILL.md`
(path from `~/.pi/secrets.json` → `skills.local_skills_dir`).

Also read `learnings.md` in the same directory and apply all Active Rules.

Execute every step in the local skill. Execute every `Check` command from Active Rules
in `learnings.md`.

**If any check fails: STOP. Fix the issue. Re-run this skill from the top.**

Do not proceed to Step 3 until all checks pass.

### Step 3: Safety Verification

Before submitting, verify:

1. **No untracked files that should be committed** — especially generated files (type definitions, lockfiles, schema dumps)
   ```bash
   git status --short
   ```
2. **No debug artifacts left behind** — binding.pry, console.log, debugger statements
   ```bash
   git diff --cached | grep -n 'binding\.pry\|byebug\|debugger\|console\.log.*TODO\|puts.*DEBUG'
   ```
3. **Commit messages are clean** — no "WIP", "fixup", "temp" unless intentional
   ```bash
   git log --oneline $(gt base 2>/dev/null || echo origin/main)..HEAD | grep -iE 'wip|fixup|temp|todo'
   ```

### Step 4: Submit

Only after all checks pass:

```bash
gt submit --stack
```

Or for a single PR:
```bash
gt submit
```

### Step 5: Report

```
✅ Pre-submit gate passed:
- Pre-commit checks: all passed
- Active learnings checked: N rules
- Safety verification: clean
- Submitted: gt submit --stack
```

Or on failure:

```
❌ Pre-submit gate FAILED — do not submit
- Failed check: <which check failed>
- Details: <what went wrong>
- Action needed: <what to fix>
```

## Why This Exists

The `pre-commit-checks` skill says "BLOCKING" and "MANDATORY" but that's an instruction,
not enforcement. This skill is the enforcement layer. It exists because:

1. In long sessions, the instruction to run pre-commit-checks can drift out of focus
2. The agent has a bias toward completing tasks quickly, which can skip validation
3. CI failures from skipped pre-commit checks cost a full CI cycle (15-45 minutes)
4. The learning loop only works if prevention actually runs

By making "submit" a skill invocation rather than a raw command, the gate is always in the
execution path.

## Integration

This skill is invoked:
- Directly by the agent before any submit/push
- By `ci-monitor` when pushing fixes (ci-monitor already references pre-commit-checks;
  this skill wraps the same contract with the submit command)

This skill depends on:
- `pre-commit-checks` (local) — the system-specific validation. Must exist at
  `local_skills_dir/pre-commit-checks/`
- `~/.pi/secrets.json` → `skills.local_skills_dir` for path resolution
