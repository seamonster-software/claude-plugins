---
name: "ntfy Notifications"
description: >
  How to use lib/notify.sh for sending push notifications.
  Covers topic structure, priority levels, action buttons,
  and the decision request pattern.
---

# ntfy Notification Reference

All Sea Monster agents send notifications through `./lib/notify.sh`.
Source this file at the start of any script that sends notifications.

```bash
source ./lib/notify.sh
```

Required environment variables:
- `NTFY_URL` — base URL of the ntfy server (e.g., `https://ntfy.seamonster.software`)
- `NTFY_PREFIX` — topic prefix (default: `seamonster`)

Optional:
- `NTFY_TOKEN` — bearer token for authenticated ntfy servers

## Topic Structure

All topics live under the `NTFY_PREFIX`:

```
{NTFY_URL}/{NTFY_PREFIX}/
├── urgent      # Blockers, failures, decisions needed NOW
├── scout       # New proposals (batch-friendly, low frequency)
├── build       # Build progress, PRs ready for review
├── ops         # Deploy status, monitoring alerts
├── growth      # Campaign results, analytics (Growth Pack)
└── digest      # Daily/weekly summaries
```

### When to Use Which Topic

| Situation | Topic | Priority | Function |
|---|---|---|---|
| Agent blocked, needs Captain decision | `urgent` | urgent | `ntfy_urgent` |
| Deployment failed, service down | `urgent` | urgent | `ntfy_urgent` |
| Security vulnerability found | `urgent` | urgent | `ntfy_urgent` |
| PR ready for review | `build` | high | `ntfy_build` |
| Build started/completed | `build` | high | `ntfy_build` |
| New proposal from Scout | `scout` | default | `ntfy_scout` |
| Market research findings | `scout` | default | `ntfy_scout` |
| Successful deployment | `ops` | default-high | `ntfy_ops` |
| Monitoring alert | `ops` | varies | `ntfy_ops` |
| Rollback executed | `ops` | high | `ntfy_ops` |
| Daily summary | `digest` | low | `ntfy_digest` |
| Weekly learnings | `digest` | low | `ntfy_digest` |

## Priority Levels

ntfy supports 5 priority levels. Sea Monster uses them as follows:

| Priority | Value | Use Case | Phone Behavior |
|---|---|---|---|
| `min` | 1 | Background info, FYI | No sound, no vibration |
| `low` | 2 | Digests, summaries | No sound |
| `default` | 3 | Normal updates, proposals | Default notification |
| `high` | 4 | PRs ready, deploys, action needed soon | Prominent notification |
| `urgent` | 5 | Blockers, failures, decisions NOW | Breaks Do Not Disturb |

Rule of thumb: if the Captain does not need to act within the hour, it is not `urgent`.

## Convenience Functions

### ntfy_urgent — Blockers and Failures

```bash
# Simple urgent notification
ntfy_urgent "Reviewer needs a decision — project-alpha #47" \
  "Auth module: JWT or session-based? Trade-offs in the issue."

# With action buttons
ntfy_urgent "Deploy failed — project-alpha" \
  "Service is down. Rolled back to previous version." \
  "view, View Logs, https://git.seamonster.software/seamonster/project-alpha/actions"
```

### ntfy_build — Build Progress

```bash
ntfy_build "PR ready for review — project-alpha #12" \
  "Auth module implementation. 3 files changed, 247 lines added."

ntfy_build "Build complete — project-alpha #47" \
  "All tests pass. Branch: issue-47-auth-module"
```

### ntfy_scout — Proposals

```bash
ntfy_scout "New opportunity — URL shortener SaaS" \
  "Monthly search volume: 12K. Competition: moderate. See proposal in bridge issue #8."
```

### ntfy_ops — Deployments and Monitoring

```bash
# Successful deploy
ntfy_ops "Deployed — project-alpha" \
  "Live at https://project-alpha.seamonster.software" \
  "high"

# Monitoring alert
ntfy_ops "High CPU — project-alpha" \
  "CPU at 92% for 5 minutes. Investigating." \
  "high"
```

### ntfy_digest — Summaries

```bash
ntfy_digest "Daily digest — March 12" \
  "3 PRs merged, 1 deployed, 2 issues blocked.\nActive: project-alpha (building), project-beta (reviewing)"
```

## Action Buttons

Action buttons let the Captain respond directly from the notification, without
opening Gitea. Two types:

### View Action (opens a URL)

```bash
action=$(ntfy_action_view "View Issue" "https://git.seamonster.software/seamonster/project-alpha/issues/47")
# Result: "view, View Issue, https://git.seamonster.software/..."

ntfy_build "PR ready — project-alpha #12" \
  "Auth module ready for review." \
  "$action"
```

### HTTP Action (POST to an API)

```bash
action=$(ntfy_action_http "Approve" \
  "https://git.seamonster.software/api/v1/repos/seamonster/project-alpha/issues/47/comments" \
  '{"body":"Approved. Proceed with implementation."}' \
  "Authorization=token ${GITEA_TOKEN},Content-Type=application/json")

ntfy_urgent "Approval needed — project-alpha #47" \
  "New proposal: URL shortener SaaS. See issue for details." \
  "$action"
```

### Multiple Actions

Separate actions with semicolons:

```bash
view_action=$(ntfy_action_view "View Issue" "${GITEA_URL}/${SEAMONSTER_ORG}/project-alpha/issues/47")
approve_action=$(ntfy_action_http "Approve" "${GITEA_URL}/api/v1/..." '{"body":"Approved"}' "...")
reject_action=$(ntfy_action_http "Reject" "${GITEA_URL}/api/v1/..." '{"body":"Rejected"}' "...")

ntfy_urgent "Decision needed" "Review the proposal." \
  "${view_action}; ${approve_action}; ${reject_action}"
```

## Decision Request Pattern

The primary Captain interaction pattern. When an agent needs a decision,
use `ntfy_decision` which combines an urgent notification with two option
buttons that post comments to the Gitea issue:

```bash
source ./lib/notify.sh

ntfy_decision \
  "Builder" \                       # crew member name
  "project-alpha" \                 # repo name
  "47" \                            # issue number
  "Database choice: PostgreSQL (scalable, more ops) or SQLite (simple, embedded)?" \
  "PostgreSQL" \                    # button 1 label
  "Use PostgreSQL for scalability" \  # button 1 comment text
  "SQLite" \                        # button 2 label
  "Use SQLite for simplicity"        # button 2 comment text
```

This sends an urgent notification with:
- Title: "Builder needs a decision — project-alpha #47"
- Body: the question
- Three buttons: [View Issue] [PostgreSQL] [SQLite]

When the Captain taps a button, it POSTs a comment to the Gitea issue:
"Decision: Use PostgreSQL for scalability" (or SQLite). This comment
triggers the `on-needs-input.yml` workflow to remove the `needs-input` label
and re-spawn the agent.

Required environment variables for `ntfy_decision`:
- `GITEA_URL`
- `GITEA_TOKEN`
- `SEAMONSTER_ORG` (default: `seamonster`)

## Raw Send Function

For custom notifications that don't fit the convenience functions:

```bash
ntfy_send \
  "custom-topic" \     # topic (appended to NTFY_PREFIX)
  "Title here" \       # title
  "Message body" \     # message
  "high" \             # priority: min, low, default, high, urgent
  "warning,tag2" \     # emoji tags (comma-separated)
  "view, Click, https://example.com"  # actions (optional)
```

## Tags (Emoji)

ntfy supports emoji tags that appear as icons on the notification.
The convenience functions set these automatically:

| Function | Tag | Emoji |
|---|---|---|
| `ntfy_urgent` | `rotating_light` | Red siren |
| `ntfy_build` | `hammer` | Hammer |
| `ntfy_scout` | `telescope` | Telescope |
| `ntfy_ops` | `anchor` | Anchor |
| `ntfy_digest` | `scroll` | Scroll |

For custom tags, pass a comma-separated string to `ntfy_send`.
See [ntfy emoji list](https://docs.ntfy.sh/emojis/) for all options.

## Health Check

```bash
status=$(ntfy_health)
if [[ "$status" == "200" ]]; then
  echo "ntfy is healthy"
else
  echo "ntfy returned HTTP ${status}"
fi
```

## Guidelines

1. Do not spam the Captain. One notification per meaningful event. Batch progress updates into a single message when possible.
2. Use `urgent` only when the Captain must act now. Overusing urgent desensitizes the Captain to real emergencies.
3. Always include enough context in the message body that the Captain can understand the situation without opening Gitea.
4. Decision requests must include the trade-offs, not just the options.
5. If an agent runs a scheduled task (scout sweep, daily digest), keep notifications brief — the Captain can open Gitea for details.
6. Include the project name and issue number in every notification title.
