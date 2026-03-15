#!/usr/bin/env bash
# Resolve a Slack display name / handle to a user ID
# Usage: slack-resolve-handle.sh <handle>
#
# Searches Slack's people directory. Strips leading @ if present.
# Outputs: USER_ID (e.g. WXXXXXXXXXX) on success, exits 1 on failure.
# Fuzzy matches are treated as failures (exits 1).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/slack-creds.sh"

HANDLE="${1:?Usage: slack-resolve-handle.sh <handle>}"
HANDLE="${HANDLE#@}"  # strip leading @

RESPONSE=$(curl -s --max-time 15 "https://slack.com/api/search.modules" \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -b "d=$SLACK_COOKIE" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=$HANDLE" \
  -d "module=people&count=3")

python3 -c "
import sys, json

handle = sys.argv[1].lower()
data = json.loads(sys.stdin.read())

if not data.get('ok'):
    print(f'ERROR: Slack API error: {data.get(\"error\", \"unknown\")}', file=sys.stderr)
    sys.exit(1)

items = data.get('items', [])
if not items:
    print(f'ERROR: No user found for \"{handle}\"', file=sys.stderr)
    sys.exit(1)

# Require exact match on display_name or workspace username
for item in items:
    profile = item.get('profile', {})
    display = profile.get('display_name_normalized', '').lower()
    name = item.get('name', '').lower()
    if handle == display or handle == name:
        print(item['id'])
        sys.exit(0)

# No exact match — report closest and fail
first = items[0]
profile = first.get('profile', {})
display = profile.get('display_name_normalized', '')
real = profile.get('real_name_normalized', '')
print(f'ERROR: No exact match for \"{handle}\". Closest: {display} ({real})', file=sys.stderr)
sys.exit(1)
" "$HANDLE" <<< "$RESPONSE"
