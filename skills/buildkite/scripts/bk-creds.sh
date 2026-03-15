#!/usr/bin/env bash
# Shared credential loader — sourced by all bk-* scripts.
# Reads token and org from ~/.pi/secrets.json

set -euo pipefail

SECRETS_FILE="$HOME/.pi/secrets.json"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Error: $SECRETS_FILE not found. Add your Buildkite token there." >&2
  exit 1
fi

BK_TOKEN=$(python3 -c "import json; print(json.load(open('$SECRETS_FILE'))['buildkite']['token'])" 2>/dev/null)
BK_ORG=$(python3 -c "import json; print(json.load(open('$SECRETS_FILE'))['buildkite']['org'])" 2>/dev/null)

if [[ -z "$BK_TOKEN" ]]; then
  echo "Error: No buildkite.token in $SECRETS_FILE" >&2
  exit 1
fi

BK_BASE="https://api.buildkite.com/v2/organizations/${BK_ORG}"
