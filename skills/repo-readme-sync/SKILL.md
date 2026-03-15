---
name: repo-readme-sync
description: "Sync skill updates to the public pi-resources repo. Only updates skills already tracked in git. New skills require explicit user confirmation before being added. Regenerates the README after changes."
---

# Repo README Sync

Sync skill changes and regenerate the README for the public pi-resources repo.

## Critical Rules

1. **Only update skills that already exist on `origin/main`.** Never add a new skill directory without explicit user confirmation.
2. **The project-local `.pi/` directory is gitignored.** Never commit or push anything from it.
3. **Run the project-local pre-push security gate before every push.**

## Procedure

### 1. Determine What Changed

```bash
cd <repo-root>

# Skills already tracked on remote
TRACKED=$(git ls-tree --name-only origin/main skills/ | sed 's|skills/||')

# Skills in the local working tree
LOCAL=$(ls -d skills/*/ 2>/dev/null | sed 's|skills/||;s|/||')

# New skills (local but not tracked)
NEW=$(comm -23 <(echo "$LOCAL" | sort) <(echo "$TRACKED" | sort))
```

### 2. Gate New Skills

If `$NEW` is non-empty, **STOP and ask the user:**

> ⚠️ The following skill(s) are not yet in the public repo:
>
> - `<skill-name>`
>
> Adding a new skill to a public repo requires manual review. Please confirm each skill is suitable for public posting. I will not add it without your explicit approval.

**Do NOT stage, commit, or push new skill directories without confirmation.** Even after confirmation, run the security scan on the new skill's files specifically.

### 3. Sync Existing Skills

For skills already tracked, copy updates from the source:

```bash
SKILLS_SRC=$(python3 -c "import json; print(json.load(open('$HOME/.pi/secrets.json'))['skills']['source_dir'])")
SKILLS_SRC="${SKILLS_SRC/#\~/$HOME}"

for skill in $TRACKED; do
  if [ -d "$SKILLS_SRC/$skill" ]; then
    cp -r "$SKILLS_SRC/$skill/"* "skills/$skill/"
  fi
done
```

### 4. Regenerate README.md

Scan `skills/*/SKILL.md` (only tracked skills, plus any user-approved new skills) and regenerate the README with:

- **Security disclaimer** at the top
- **Summary table** — skill name, one-sentence description, last-updated date
- **Per-skill detail sections** — what it does, scripts table, dependencies
- **Integration map** — how skills connect
- **Setup section** — prerequisites, install, secrets schema, local pre-push gate instructions

#### Summary Table Rules

- Sort alphabetically by skill name
- Description is the **first sentence only** from the frontmatter description
- Updated date from `git log -1 --pretty=format:"%as" -- skills/<name>/`

#### Setup Section Must Include

Instructions for creating the local pre-push security gate:

```markdown
### Local Pre-Push Gate

Create a project-local skill that runs the security scan before every push.
This skill is gitignored and never leaves your machine:

\`\`\`bash
mkdir -p .pi/skills/pre-push-security-gate
\`\`\`

Create `.pi/skills/pre-push-security-gate/SKILL.md` with instructions to:
1. Run `skills/security/scripts/scan-secrets.sh` against the repo
2. Audit the staged diff for secrets
3. Block new skills from being added without explicit confirmation
\`\`\`
```

### 5. Consistency Check — Skills ↔ README

After generating the README, verify that **every skill's SKILL.md is consistent with the README's architecture**. This is bidirectional:

- **README → Skills:** Does the README accurately describe what each skill does?
- **Skills → README:** Does each skill's self-description and stated role match how the README and Integration Map position it?

#### What to Check

For each skill, compare:

1. **Role** — Does the skill's description of its own role match the README's description? (e.g., if the README says a skill is "a scanner tool, not the enforcer," the SKILL.md must not say "BLOCKING GATE" or "most critical skill")
2. **Dependencies** — Does the skill's dependency list match what the README says it depends on?
3. **Integration** — Does the skill's description of how it interacts with other skills match the Integration Map?
4. **Summary table** — Is the one-sentence description in the table an accurate summary of the SKILL.md's frontmatter?

#### How to Check

Read each `skills/*/SKILL.md` and cross-reference against:
- The corresponding detail section in the README
- The Integration Map
- The dependency listings

If any inconsistency is found:

> ⚠️ Consistency check failed:
>
> - `security` SKILL.md says "<X>" but README says "<Y>"
>
> Fixing the SKILL.md to match the current architecture.

Fix the SKILL.md (not the README — the README is the source of truth for architecture). Then re-run the consistency check.

#### Why This Exists

Architecture changes (like moving from a single-layer security gate to a two-layer model) update the README but can leave individual SKILL.md files stale. This check catches that drift.

### 6. Security Gate

Before committing or pushing, invoke the project-local pre-push gate:

```bash
# The model should read and follow .pi/skills/pre-push-security-gate/SKILL.md
```

This runs the scanner, audits the diff, and blocks new unapproved skills.

### 7. Commit and Push

```bash
git add README.md skills/  # only tracked skill dirs
git commit -m "docs: sync README with current skills inventory"
git push origin main
```
