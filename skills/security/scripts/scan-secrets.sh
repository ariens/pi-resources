#!/usr/bin/env bash
# Scan a directory for secrets, tokens, internal URLs, and company-sensitive data.
# Reads patterns from ~/.pi/agent/secrets.json so the script itself contains no sensitive data.
#
# Usage: scan-secrets.sh [directory]
#   directory: path to scan (default: current directory)
#
# Exit codes:
#   0 = clean
#   1 = findings detected
#   2 = configuration error
#
# NOTE: Uses grep -E (extended regex) for macOS/Linux portability. NOT grep -P.

set -euo pipefail

SECRETS_FILE="$HOME/.pi/agent/secrets.json"
SCAN_DIR="${1:-.}"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "ERROR: $SECRETS_FILE not found." >&2
  exit 2
fi

# ─── Load company config ───

COMPANY_NAME=$(python3 -c "import json; print(json.load(open('$SECRETS_FILE'))['company']['name'])" 2>/dev/null)
COMPANY_DOMAINS=$(python3 -c "import json; print('\n'.join(json.load(open('$SECRETS_FILE'))['company']['domains']))" 2>/dev/null)
COMPANY_ORGS=$(python3 -c "import json; print('\n'.join(json.load(open('$SECRETS_FILE'))['company']['orgs']))" 2>/dev/null)
INTERNAL_URLS=$(python3 -c "import json; print('\n'.join(json.load(open('$SECRETS_FILE'))['company']['internal_url_patterns']))" 2>/dev/null)

# ─── Load actual secret values to scan for ───

SECRET_VALUES=$(python3 -c "
import json, re

def is_secret_like(s):
    if s.startswith(('~/', '/', './', '../')): return False
    if re.match(r'^https?://[a-zA-Z0-9._-]+/?$', s): return False
    if len(s) < 16 and re.match(r'^[a-zA-Z0-9_-]+$', s): return False
    if re.match(r'^[a-z0-9.-]+\.[a-z]{2,}$', s): return False
    return True

def extract_strings(obj, path=''):
    if isinstance(obj, str) and len(obj) > 8:
        if is_secret_like(obj):
            print(obj)
    elif isinstance(obj, dict):
        for k, v in obj.items():
            extract_strings(v, f'{path}.{k}')
    elif isinstance(obj, list):
        for item in obj:
            extract_strings(item, path)

data = json.load(open('$SECRETS_FILE'))
extract_strings(data)
" 2>/dev/null)

# Also extract the real user_id and dm_channel values specifically
SLACK_USER_ID=$(python3 -c "import json; print(json.load(open('$SECRETS_FILE')).get('slack',{}).get('user_id',''))" 2>/dev/null)
SLACK_DM_CHANNEL=$(python3 -c "import json; print(json.load(open('$SECRETS_FILE')).get('slack',{}).get('dm_channel',''))" 2>/dev/null)

# ─── File inclusion pattern ───

INCLUDE_ARGS="--include=*.md --include=*.sh --include=*.json --include=*.yml --include=*.yaml --include=*.ts --include=*.js --include=*.rb --include=*.py"

# ─── Build grep patterns ───

FINDINGS=0
REPORT=""

scan_pattern() {
  local label="$1"
  local pattern="$2"
  local mode="${3:-regex}"  # "regex" or "fixed"

  local grep_flag="-rEn"
  [[ "$mode" == "fixed" ]] && grep_flag="-rFn"
  [[ "$mode" == "iregex" ]] && grep_flag="-riEn"

  local matches
  matches=$(grep $grep_flag $INCLUDE_ARGS "$pattern" "$SCAN_DIR" 2>/dev/null \
    | grep -v "node_modules/" \
    | grep -v "\.git/" \
    | grep -v "scan-secrets\.sh" \
    | grep -v 'SKILL\.md.*secrets\.json' \
    | grep -v 'README\.md.*bkua_\.\.\.' \
    | grep -v 'README\.md.*xoxc-\.\.\.' \
    | grep -v 'README\.md.*xoxd-\.\.\.' \
    | grep -v 'README\.md.*"token":' \
    | grep -v 'README\.md.*WXXXXXXXX' \
    | grep -v 'README\.md.*DXXXXXXXX' \
    | grep -v 'README\.md.*CXXXXXXXX' \
    | grep -v 'README\.md.*U01ABC123' \
    | grep -v 'README\.md.*your-workspace' \
    | grep -v 'README\.md.*yourco' \
    | grep -v 'README\.md.*Your Company' \
    | grep -v 'README\.md.*your-org' \
    || true)

  if [[ -n "$matches" ]]; then
    FINDINGS=$((FINDINGS + 1))
    REPORT+="
🔴 $label
$matches
"
  fi
}

# ─── 1. Token patterns ───

scan_pattern "Buildkite tokens (bkua_)" 'bkua_[a-f0-9]{20,}'
scan_pattern "Slack tokens (xoxc-)" 'xoxc-[0-9]+-[0-9]+-[0-9]+-[a-f0-9]{20,}'
scan_pattern "Slack cookies (xoxd-)" 'xoxd-[A-Za-z0-9%]{20,}'
scan_pattern "Generic API keys/tokens" '(api[_-]?key|api[_-]?token|secret[_-]?key|access[_-]?token|auth[_-]?token)[[:space:]]*[:=][[:space:]]*['"'"'"][a-zA-Z0-9_-]{16,}' "iregex"
scan_pattern "Bearer tokens" 'Bearer[[:space:]]+[a-zA-Z0-9_.-]{20,}'
scan_pattern "Private keys" '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'
scan_pattern "AWS credentials" '(AKIA|ASIA)[A-Z0-9]{16}'
scan_pattern "GitHub tokens" '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{36,}'
scan_pattern "Okta application IDs" '0oa[a-zA-Z0-9]{10,}'

# ─── 2. Internal URLs ───

while IFS= read -r url; do
  [[ -z "$url" ]] && continue
  scan_pattern "Internal URL: $url" "$url" "fixed"
done <<< "$INTERNAL_URLS"

# ─── 3. Slack user/channel IDs (exact values from secrets) ───

if [[ -n "$SLACK_USER_ID" && ${#SLACK_USER_ID} -gt 4 ]]; then
  scan_pattern "Slack user ID ($SLACK_USER_ID)" "$SLACK_USER_ID" "fixed"
fi
if [[ -n "$SLACK_DM_CHANNEL" && ${#SLACK_DM_CHANNEL} -gt 4 ]]; then
  scan_pattern "Slack DM channel ID ($SLACK_DM_CHANNEL)" "$SLACK_DM_CHANNEL" "fixed"
fi

# ─── 4. Exact secret values from secrets.json ───

while IFS= read -r secret; do
  [[ -z "$secret" ]] && continue
  [[ ${#secret} -lt 12 ]] && continue
  fingerprint="${secret:0:20}"
  matches=$(grep -rFn "$fingerprint" "$SCAN_DIR" $INCLUDE_ARGS 2>/dev/null \
    | grep -v "\.git/" \
    | grep -v "node_modules/" \
    | grep -v "scan-secrets\.sh" \
    || true)
  if [[ -n "$matches" ]]; then
    FINDINGS=$((FINDINGS + 1))
    REPORT+="
🔴 Verbatim secret value found (from secrets.json)
$matches
"
  fi
done <<< "$SECRET_VALUES"

# ─── 5. Company-specific internal repo paths ───

while IFS= read -r org; do
  [[ -z "$org" ]] && continue
  scan_pattern "Internal repo reference: $org/" "github\.com[/:]${org}/" "iregex"
done <<< "$COMPANY_ORGS"

# ─── 6. Company name references ───

if [[ -n "$COMPANY_NAME" ]]; then
  scan_pattern "Company name: $COMPANY_NAME" "$COMPANY_NAME" "fixed"
fi

# ─── 7. Company domains ───

while IFS= read -r domain; do
  [[ -z "$domain" ]] && continue
  scan_pattern "Company domain: $domain" "$domain" "fixed"
done <<< "$COMPANY_DOMAINS"

# ─── Report ───

if [[ $FINDINGS -gt 0 ]]; then
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║  🚨 SECURITY SCAN FAILED — $FINDINGS finding(s) detected     ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo "$REPORT"
  echo "─────────────────────────────────────────────────────────────"
  echo "Fix all findings before pushing. Secrets belong in ~/.pi/agent/secrets.json only."
  exit 1
else
  echo "✅ Security scan passed — no secrets or sensitive data found."
  exit 0
fi
