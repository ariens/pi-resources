---
name: pr-review-request-slack-message
description: Generate and post a Slack PR review request message. Fetches the GitHub sub-issue for context (title, parent issue, step N/total, Slack channel, CC channels, ping users), composes the message, previews via DM, posts to the designated channel, and x-posts to CC channels. Use when the user asks to draft, post, or announce a PR review request.
---

# PR Review Request — Slack Message

Generate a Slack-formatted PR review request, preview it via DM, post to the designated Slack channel, and x-post to CC channels.

## Step 1: Gather Context

Use `gh issue view <sub-issue-url> --json title,body` and `gh issue view <parent-issue-url> --json title` to collect:

- Sub-issue title, body, and URL
- Parent issue title and URL
- Step number and total (from the parent issue's task list or the sub-issue body)

### Parse Slack Metadata from the Sub-Issue

Look near the **top of the sub-issue body** for these declarations:

```
Slack channel: #primary-channel
Slack channels for CC: #channel-1, #channel-2
Slack users to ping: @handle_1, @handle_2
```

All three are optional. Rules:

- **Slack channel** — The primary channel for the review request. **MUST be explicitly declared. Never infer, guess, or assume a channel.** If missing, warn the user:

  > ⚠️ No Slack channel declared in the sub-issue. Add one near the top of the issue body, e.g.:
  > `Slack channel: #your-channel-name`
  >
  > I'll still generate the message and copy it to your clipboard, but I can't post it.

  Then proceed with message generation and clipboard copy only — skip Steps 3–6.

- **Slack channels for CC** — Additional channels that receive an x-post with a link to the primary message. Optional.

- **Slack users to ping** — Slack handles to `cc:` at the end of the primary message. Optional.

## Step 2: Validate All Slack References

**This step is a gate. ALL channels and handles must resolve before proceeding. Do NOT skip or partial-proceed.**

Validate every Slack reference parsed in Step 1. Collect all failures, then report them together.

### Validate Channels

For the primary channel and every CC channel, run:

```bash
CHANNEL_ID=$(<skill-dir>/scripts/slack-validate-channel.sh "#channel-name")
```

The script outputs a channel ID (e.g. `C09TXAEFQMB`) on success, or exits 1 with an error message.

### Resolve User Handles

For each handle in `Slack users to ping`, run:

```bash
USER_ID=$(<skill-dir>/scripts/slack-resolve-handle.sh "@handle_name")
```

The script outputs a user ID (e.g. `WXXXXXXXXXX`) on success, or exits 1 with an error message. If the script writes a `WARN:` to stderr (fuzzy match), treat it as a failure.

### Gate Check

Run ALL validations (do not stop at the first failure). Then:

- **If any failed:** Report every failure to the user and **abort the entire operation**. Do not compose, preview, or post anything. Format:

  > 🚫 Aborting — the following Slack references could not be resolved:
  >
  > - Channel `#bad-channel-name` — not found
  > - Handle `@bad.handle` — no user found
  > - Handle `@ambiguous.name` — no exact match (fuzzy match is not accepted)
  >
  > Fix these in the sub-issue and try again.

- **If all passed:** Proceed to Step 3 with the resolved channel IDs and user IDs.

## Step 3: Compose the Message

Write the message to `/tmp/slack-message.md` and copy it to the clipboard: `cat /tmp/slack-message.md | pbcopy`

### Format Rules

- Use Slack-compatible markdown: `*bold*`, `_italic_`, `:emoji:`, `` `code` ``
- Links: `[description](url)` format (the post script converts to Slack `<url|text>`)
- Keep it concise — the audience is already aware of the project context
- No file/diff statistics unless explicitly asked

### Message Structure

1. **Opening line** — `:pr-open: Ready for review: [PR title](PR url) :eyes:`
2. **Brief description** — What the PR does in 1–2 sentences. Include enough technical detail to be useful.
3. **Closing line** — Issue linkage:
   ```
   Closes [<sub-issue title>](<sub-issue url>) (step <N> / <total>) in support of [<parent issue title>](<parent issue url>)
   ```
4. **CC line** (only if `Slack users to ping` is defined) — Append on a new line:
   ```
   cc: <@USER_ID_1> <@USER_ID_2>
   ```
   Use the resolved user IDs from Step 2, NOT the raw handles. The `<@...>` syntax creates real Slack mentions.

### Example (with CC)

```
:pr-open: Ready for review: [Add config entries for new service app](https://github.com/your-org/your-repo/pull/12345) :eyes:

Registers the new service app in the platform config layer. Adds the frozen record entry and the dev-only config entry for local development. Config-only — no behavioral changes.

Closes [Config PR — register new service app](https://github.com/your-org/your-tracker/issues/10) (step 1 / 7) in support of [New Service App: Implementation](https://github.com/your-org/your-tracker/issues/1)

cc: <@WXXXXXXXXXX> <@UXXXXXXXXXX>
```

## Step 4: Preview via DM and Confirm

Send 3 DM preview messages (or 2 if no CC channels are declared). These are exact copies of what will be posted for real — no extra footers, no modifications.

```bash
DM_CHANNEL=$(python3 -c "import json; print(json.load(open('$HOME/.pi/secrets.json'))['slack']['dm_channel'])")
```

**DM 1 — Primary channel message preview:**

Post `/tmp/slack-message.md` as-is (this is the exact message that will go to the primary channel):

```bash
<skill-dir>/scripts/slack-post.sh "$DM_CHANNEL"
```

**DM 2 — CC plan** (skip if no `Slack channels for CC` declared):

Write the following to `/tmp/slack-dm-cc-plan.md` and post it:

```
The above message will be posted to *#primary-channel*. The following x-post will also be sent to: #cc-channel-1, #cc-channel-2
```

```bash
<skill-dir>/scripts/slack-post.sh "$DM_CHANNEL" /tmp/slack-dm-cc-plan.md
```

**DM 3 — X-post message preview** (skip if no `Slack channels for CC` declared):

Write the x-post message to `/tmp/slack-xpost.md` using a placeholder permalink, then post it:

```
x-post for vis: https://your-workspace.slack.com/archives/PLACEHOLDER/p0000000000000000
```

```bash
<skill-dir>/scripts/slack-post.sh --unfurl "$DM_CHANNEL" /tmp/slack-xpost.md
```

Note: the placeholder link won't unfurl in the preview — that's expected. The real x-post in Step 6 will use the actual permalink and unfurl correctly.

After sending all DMs, tell the user:

```
✅ Preview sent to your DM (3 messages). Check them in Slack. Ready to post?
```

**STOP here and wait for the user to confirm.** Do NOT proceed to Step 5 until the user explicitly says yes. Nothing is posted to any real channel (primary or CC) without user confirmation.

## Step 5: Post to Primary Channel

**Only after the user confirms in Step 4.** Post to the real channel:

```bash
<skill-dir>/scripts/slack-post.sh "#primary-channel"
```

The script outputs: `OK channel=C123 ts=1234.5678 permalink=https://...`

**Save the permalink** — it is needed for x-posting in Step 6.

Report success to the user.

## Step 6: X-Post to CC Channels

**Skip this step if no `Slack channels for CC` were declared in the sub-issue.**

For each CC channel, write a minimal x-post message to `/tmp/slack-xpost.md`:

```
x-post for vis: <permalink from Step 5>
```

Then post with `--unfurl` so Slack shows a preview of the original message:

```bash
<skill-dir>/scripts/slack-post.sh --unfurl "#cc-channel" /tmp/slack-xpost.md
```

Repeat for each CC channel. Report each success/failure.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/slack-creds.sh` | Shared credential loader. Sourced by all other scripts. |
| `scripts/slack-post.sh [--unfurl] <channel> [file]` | Post a message. Returns `OK channel=… ts=… permalink=…` |
| `scripts/slack-validate-channel.sh <channel>` | Validate channel exists. Returns channel ID or exits 1 |
| `scripts/slack-resolve-handle.sh <handle>` | Resolve `@handle` → Slack user ID or exits 1. Fuzzy matches are failures. |

## Prerequisites

- **python3** — required by all scripts for JSON handling and payload construction
- **curl** — required for Slack API calls
- **macOS** — `pbcopy` is used for clipboard copy (Linux users: substitute `xclip -selection clipboard`)

## Secrets

This skill reads Slack credentials from `~/.pi/secrets.json` (should be `chmod 600`):

```json
{
  "slack": {
    "token": "xoxc-...",
    "cookie": "xoxd-...",
    "user_id": "WXXXXXXXXXX",
    "dm_channel": "DXXXXXXXXXX",
    "workspace_url": "https://your-workspace.slack.com"
  }
}
```

`workspace_url` is optional — defaults to the value in `~/.pi/secrets.json` if omitted.

No secrets are stored in the skill itself.
