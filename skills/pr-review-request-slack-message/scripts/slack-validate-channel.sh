#!/usr/bin/env bash
# Validate that a Slack channel exists and is accessible
# Usage: slack-validate-channel.sh <channel_name>
#
# channel_name: e.g. #proj-foo or proj-foo (leading # stripped)
# Outputs: CHANNEL_ID (e.g. C09TXAEFQMB) on success, exits 1 on failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/slack-creds.sh"

CHANNEL="${1:?Usage: slack-validate-channel.sh <channel_name>}"
CHANNEL="${CHANNEL#\#}"  # strip leading #

RESPONSE=$(curl -s --max-time 15 "https://slack.com/api/search.modules" \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -b "d=$SLACK_COOKIE" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=$CHANNEL" \
  -d "module=channels&count=5")

python3 -c "
import sys, json

channel = sys.argv[1].lower()
data = json.loads(sys.stdin.read())

if not data.get('ok'):
    print(f'ERROR: Slack API error: {data.get(\"error\", \"unknown\")}', file=sys.stderr)
    sys.exit(1)

items = data.get('items', [])
if not items:
    print(f'ERROR: Channel \"#{channel}\" not found', file=sys.stderr)
    sys.exit(1)

# Require exact match on channel name
for item in items:
    name = item.get('name', '').lower()
    if name == channel:
        print(item['id'])
        sys.exit(0)

# No exact match
names = [item.get('name', '') for item in items]
print(f'ERROR: No exact match for \"#{channel}\". Closest: {\", \".join(\"#\" + n for n in names)}', file=sys.stderr)
sys.exit(1)
" "$CHANNEL" <<< "$RESPONSE"
