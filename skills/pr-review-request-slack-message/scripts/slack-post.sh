#!/usr/bin/env bash
# Post a message to a Slack channel using credentials from ~/.pi/secrets.json
# Usage: slack-post.sh [--unfurl] <channel_id_or_name> [message_file]
#
# Options:
#   --unfurl    Enable link unfurling (used for x-post messages with previews)
#
# channel_id_or_name: Slack channel ID (C/D...) or channel name (#channel-name)
# message_file: path to message file (default: /tmp/slack-message.md)
#
# Output on success: OK channel=<id> ts=<ts> permalink=<url>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/slack-creds.sh"

UNFURL="false"
if [[ "${1:-}" == "--unfurl" ]]; then
  UNFURL="true"
  shift
fi

CHANNEL="${1:?Usage: slack-post.sh [--unfurl] <channel> [message_file]}"
MESSAGE_FILE="${2:-/tmp/slack-message.md}"

if [[ ! -f "$MESSAGE_FILE" ]]; then
  echo "ERROR: Message file not found: $MESSAGE_FILE" >&2
  exit 1
fi

# Build JSON payload in a temp file — avoids shell expansion issues with $PAYLOAD
PAYLOAD_FILE=$(mktemp "${TMPDIR:-/tmp}/slack-payload-XXXXXX.json")
trap 'rm -f "$PAYLOAD_FILE"' EXIT

python3 - "$MESSAGE_FILE" "$CHANNEL" "$UNFURL" > "$PAYLOAD_FILE" << 'PYEOF'
import json, re, sys

message_file = sys.argv[1]
channel = sys.argv[2]
unfurl = sys.argv[3] == "true"

with open(message_file) as f:
    text = f.read().strip()

# Convert markdown links [text](url) to Slack format <url|text>
text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<\2|\1>', text)

print(json.dumps({
    "channel": channel,
    "text": text,
    "unfurl_links": unfurl
}))
PYEOF

RESPONSE=$(curl -s --max-time 15 https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -b "d=$SLACK_COOKIE" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d "@$PAYLOAD_FILE")

# Parse response once, extract all fields
eval "$(python3 -c "
import sys, json
data = json.loads(sys.argv[1])
ok = data.get('ok', False)
print(f'RESP_OK={str(ok)!r}')
if ok:
    print(f'RESP_CHANNEL={data[\"channel\"]!r}')
    print(f'RESP_TS={data[\"ts\"]!r}')
else:
    print(f'RESP_ERROR={data.get(\"error\", \"unknown\")!r}')
" "$RESPONSE")"

if [[ "$RESP_OK" == "True" ]]; then
  TS_NO_DOT=$(echo "$RESP_TS" | tr -d '.')
  PERMALINK="${SLACK_WORKSPACE_URL}/archives/${RESP_CHANNEL}/p${TS_NO_DOT}"
  echo "OK channel=$RESP_CHANNEL ts=$RESP_TS permalink=$PERMALINK"
else
  echo "ERROR: $RESP_ERROR" >&2
  echo "$RESPONSE" >&2
  exit 1
fi
