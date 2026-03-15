#!/usr/bin/env bash
# Shared credential loader for Slack scripts.
# Source this file: source "$(dirname "$0")/slack-creds.sh"
#
# Exports: SLACK_TOKEN, SLACK_COOKIE, SLACK_WORKSPACE_URL
# Requires: python3, ~/.pi/secrets.json with .slack.token and .slack.cookie

SECRETS_FILE="$HOME/.pi/secrets.json"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "ERROR: $SECRETS_FILE not found. Create it with slack.token and slack.cookie." >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 is required but not found on PATH." >&2
  exit 1
fi

# Validate permissions (warn if world-readable)
# Detect GNU stat (nix) vs BSD stat (macOS native)
if stat --version &>/dev/null 2>&1; then
  PERMS=$(stat -c '%a' "$SECRETS_FILE")
elif [[ "$(uname)" == "Darwin" ]]; then
  PERMS=$(/usr/bin/stat -f '%Lp' "$SECRETS_FILE")
else
  PERMS=$(stat -c '%a' "$SECRETS_FILE")
fi
if [[ "$PERMS" != "600" ]]; then
  echo "WARN: $SECRETS_FILE has permissions $PERMS (expected 600). Run: chmod 600 $SECRETS_FILE" >&2
fi

# Extract all credentials in a single python3 call
eval "$(python3 -c "
import json, os
s = json.load(open(os.path.expanduser('~/.pi/secrets.json')))['slack']
print(f'export SLACK_TOKEN={s[\"token\"]!r}')
print(f'export SLACK_COOKIE={s[\"cookie\"]!r}')
print(f'export SLACK_WORKSPACE_URL={s.get(\"workspace_url\", \"https://your-workspace.slack.com\")!r}')
")"
