---
name: security
description: "Scanner tool that detects secrets, tokens, internal URLs, company-sensitive data, and verbatim credential values in repo files. Called by the project-local pre-push gate before every push. All patterns loaded from ~/.pi/agent/secrets.json at runtime — the script itself contains zero sensitive data."
---

# Security

Scanner tool that detects secrets, tokens, internal URLs, and company-sensitive data in repo files.

**This skill is the scanner, not the enforcer.** Enforcement is handled by the project-local pre-push gate (`.pi/skills/pre-push-security-gate/`, gitignored, never pushed) which calls this scanner as one of its checks. See the README's Integration Map for the full architecture.

## What It Scans For

1. **Token patterns** — Buildkite (`bkua_`), Slack (`xoxc-`, `xoxd-`), GitHub (`ghp_`, `gho_`), AWS (`AKIA`), Bearer tokens, API keys, private keys, Okta application IDs
2. **Internal URLs** — loaded from `~/.pi/agent/secrets.json` under `company.internal_url_patterns`
3. **Slack IDs** — real user IDs and DM channel IDs from `~/.pi/agent/secrets.json`
4. **Verbatim secret values** — every credential-like string from `~/.pi/agent/secrets.json` is fingerprinted and scanned for
5. **Internal repo references** — `github.com/<org>/` for every org listed in `company.orgs`
6. **Company name and domains** — loaded from `~/.pi/agent/secrets.json` under `company.name` and `company.domains`

All patterns are loaded from `~/.pi/agent/secrets.json` at runtime. **The scan script itself contains zero sensitive data.**

## Configuration

The skill reads company-specific config from `~/.pi/agent/secrets.json`:

```json
{
  "company": {
    "name": "Acme Corp",
    "domains": ["acme.com", "acme.io"],
    "orgs": ["acme", "acme-internal"],
    "internal_url_patterns": ["vault.acme.io", "internal.acme.com"]
  }
}
```

To adapt this for a different company, update the `company` block. No skill files need to change.

## Usage

```bash
<skill-dir>/scripts/scan-secrets.sh /path/to/repo
```

Exit codes:
- `0` — clean
- `1` — findings detected
- `2` — configuration error

### What to Do When the Scan Fails

1. **Read the findings** — the report shows exactly which files and lines matched
2. **Move secrets to `~/.pi/agent/secrets.json`** — tokens, keys, and credentials belong there, never in repo files
3. **Replace hardcoded values with references** — read from `~/.pi/agent/secrets.json` at runtime
4. **Use placeholders in documentation** — `bkua_...`, `xoxc-...`, `WXXXXXXXX`
5. **Re-run the scan** to confirm clean

## Role in the Architecture

```
LOCAL pre-push gate (.pi/, gitignored)
  │
  ├─ 1. Calls this scanner (scan-secrets.sh)
  ├─ 2. Audits staged diff
  └─ 3. Blocks unapproved new skills

This skill = step 1 only.
```

Skills that push to this repo (`ci-monitor`, `repo-readme-sync`) follow the local pre-push gate, which calls this scanner. They do not call this scanner directly.

## For the Model

**When writing or modifying any file in the personal repo:**

1. NEVER include real token values — use `bkua_...`, `xoxc-...`, etc.
2. NEVER include internal URLs — use `https://your-internal-tool.example.com`
3. NEVER include real Slack user/channel IDs — use `WXXXXXXXX`, `CXXXXXXXX`
4. NEVER reference internal GitHub org repos by real name in hardcoded strings
5. ALWAYS load sensitive config from `~/.pi/agent/secrets.json` at runtime
6. ALWAYS follow the project-local pre-push gate before pushing — do not call this scanner directly as a substitute
