---
name: "Escalation Protocol"
description: >
  When and how to escalate to the Captain. Write blocker questions with
  options and trade-offs to the order file, set status to needs-input,
  send ntfy notification, and move on to other work.
---

# Escalation Protocol

Agents never stall silently. When blocked, they write a structured question
to the order file, notify the Captain, and move on to other work.

## When to Escalate

Escalate when:
- A design decision is needed that is not covered by the project's CLAUDE.md or existing order context
- Two valid approaches exist and the trade-offs require Captain judgment
- An external dependency is unavailable or broken (third-party API down, service unreachable)
- A security concern requires human review before proceeding
- The order requirements are ambiguous or contradictory
- Budget, pricing, or business strategy decisions are involved
- You have been working on a problem for more than 15 minutes without progress

Do NOT escalate when:
- The answer is in the project CLAUDE.md, order file context, or existing code
- The question is purely technical with a clear best practice
- You can make a reasonable default choice and document it for later review
- The issue is a known bug with an obvious fix

## How to Format the Question

Every escalation follows this structure:

```
**Question:** [One clear sentence]

**Option A: [Name]**
- [Pro 1]
- [Pro 2]
- [Con 1]

**Option B: [Name]**
- [Pro 1]
- [Pro 2]
- [Con 1]

**Recommendation:** [Which option and why, or "No recommendation — genuinely unclear"]
```

### Good Escalation

```
**Question:** Should user sessions persist across server restarts?

**Option A: In-memory sessions (simpler)**
- No Redis dependency
- Faster session lookups
- Users lose sessions on every deploy or restart
- Not viable if we scale to multiple servers

**Option B: Redis-backed sessions**
- Sessions survive restarts and deploys
- Required for multi-server scaling
- Adds Redis as a dependency (Sysadmin needs to set it up)
- Slightly more complex configuration

**Recommendation:** Redis-backed sessions. The deploy-restart issue alone
makes in-memory impractical for a production service, and Redis is lightweight.
```

### Bad Escalation

```
What database should I use?
```

This is bad because: no options, no trade-offs, no context, no recommendation.
The Captain has to do all the thinking.

## The Escalation Flow

### Step 1: Write the Blocker to the Order File

Open the order file (e.g., `.bridge/orders/005-build-auth.md`) and write the
question to the `## Blocker` section. If the section does not exist, create it.

```markdown
## Blocker

**Agent:** Builder
**Date:** 2026-03-13

**Question:** Should user sessions persist across server restarts?

**Option A: In-memory sessions**
- No Redis dependency, simpler setup
- Users lose sessions on deploy/restart
- Cannot scale to multiple servers

**Option B: Redis-backed sessions**
- Sessions survive restarts
- Required for multi-server scaling
- Adds Redis dependency

**Recommendation:** Redis-backed — deploy restarts would break all user sessions otherwise.
```

### Step 2: Set Status to `needs-input`

Update the YAML frontmatter in the order file:
1. Save the current `status` value to a `previous_status` field
2. Set `status: needs-input`

Before:
```yaml
---
id: 005
title: Build auth module
status: building
priority: p1
branch: order-005-auth
---
```

After:
```yaml
---
id: 005
title: Build auth module
status: needs-input
previous_status: building
priority: p1
branch: order-005-auth
---
```

The `previous_status` field is critical — when the Captain responds, the status
reverts to this value so the agent can resume where it left off.

### Step 3: Send ntfy Notification (Best Effort)

Read the ntfy topic from `.bridge/config.yml` and send a notification. This is
best effort — if ntfy is unreachable or not configured, continue without error.

```bash
# Read ntfy topic from config
NTFY_TOPIC=$(grep -E '^ntfy_topic:' .bridge/config.yml 2>/dev/null | awk '{print $2}')

# Send notification (best effort — never fail on this)
if [[ -n "${NTFY_TOPIC:-}" ]]; then
  curl -s \
    -H "Title: Blocked: Order #005 — Build auth module" \
    -H "Priority: high" \
    -H "Tags: construction,question" \
    -d "Builder needs a decision: Should user sessions persist across server restarts?

Option A: In-memory sessions
Option B: Redis-backed sessions

Recommendation: Redis-backed" \
    "$NTFY_TOPIC" 2>/dev/null || true
fi
```

The notification should include:
- **Title:** `Blocked: Order #NNN — [order title]`
- **Priority:** Match the escalation priority (see table below)
- **Body:** The question, options (short summary), and recommendation
- Keep it concise — the Captain reads on a phone

### Step 4: Return

After writing the blocker and sending the notification, **return immediately**.
Do not wait for a response. Do not poll. The `/x:work` loop will pick up other
actionable orders.

```
# Agent's final action:
# 1. Blocker written to order file
# 2. Status set to needs-input
# 3. ntfy sent (best effort)
# 4. Return — /x:work will find other work
```

## How the Captain Responds

The Captain has three channels to respond. All three result in the same outcome.

### Channel 1: ntfy Reply

The Captain replies to the blocker notification from their phone. The next
`/x:work` cycle reads inbound ntfy messages, finds the reply, and applies
the Captain's decision to the order file.

### Channel 2: `/x:voyage` (Interactive)

The Captain runs `/x:voyage` in the terminal. Voyage shows all orders with
`status: needs-input` and lets the Captain respond interactively. The response
is written to the order file immediately.

### Channel 3: Direct File Edit

The Captain edits the order file directly — adds their decision to the
`## Blocker` section and changes `status` back to `previous_status` manually.

### What Happens When a Response Arrives

Regardless of channel, the same thing happens:

1. The Captain's decision is appended to the `## Blocker` section:

```markdown
## Blocker

**Agent:** Builder
**Date:** 2026-03-13

**Question:** Should user sessions persist across server restarts?

**Option A: In-memory sessions**
- No Redis dependency, simpler setup
- Users lose sessions on deploy/restart

**Option B: Redis-backed sessions**
- Sessions survive restarts
- Adds Redis dependency

**Recommendation:** Redis-backed.

---

**Captain's Decision (2026-03-13):** Go with Redis-backed sessions. Use the
managed Redis on Hetzner, no need to self-host.
```

2. Status reverts from `needs-input` to `previous_status` (e.g., `building`)
3. The `previous_status` field is removed from frontmatter
4. The next `/x:work` cycle sees the order is actionable again and dispatches
   the agent to resume
5. The decision is permanently recorded in the order file — part of the
   git history forever

## Escalation Priority

Not all escalations are equally urgent. Set the ntfy notification priority
to match the impact:

| Situation | ntfy Priority |
|---|---|
| Service is down in production | `urgent` |
| Security vulnerability found | `urgent` |
| Blocker that halts all build progress | `urgent` |
| Design decision, other work available | `high` |
| Nice-to-have question, low impact | `default` |
| Non-blocking feedback request | `low` |

## Multiple Blockers

If an agent hits multiple blockers on the same order:
- Write all questions in the same `## Blocker` section, clearly numbered
- Send one ntfy notification summarizing all blockers
- The Captain can respond to them all at once or individually

If blockers span multiple orders:
- Each order gets its own `## Blocker` section updated
- Each order gets its own ntfy notification
- Each order independently transitions to `needs-input`

## Cascading Escalation

Sometimes a question from one agent should be redirected to another. In the
file-based flow, the agent notes the redirect in the blocker section:

```markdown
## Blocker

**Agent:** Builder
**Redirect to:** Architect

**Question:** The data model requires either a relational schema (normalized, SQL)
or a document store (denormalized, MongoDB). This decision affects the entire
service layer. Needs Architect's input before proceeding.
```

Common redirects:

| Original Agent | Question Type | Redirect To |
|---|---|---|
| Builder | Architecture decision | Architect |
| Builder | Timeline/scope | Planner |
| Deployer | System-level dependency | Sysadmin |
| Any agent | Security concern | Security |
| Any agent | Unclear requirements | Captain (via ntfy) |

When redirecting, the order still gets `status: needs-input`. The `/x:work`
loop or Captain routes the question to the right agent.

## Timeout Handling

If a blocked order receives no response within 48 hours:
- The `/x:work` cycle mentions it in the ntfy summary as "still awaiting input"
- After 7 days, `/x:work` re-sends the ntfy notification
- After 14 days, the order is flagged as a stale blocker in `/x:voyage` output

Agents do not poll for responses. The `/x:work` loop handles re-triggering
automatically when the status changes.

## Rules

1. Never stall silently. If you are blocked, escalate.
2. Always provide options with trade-offs. Never ask open-ended questions.
3. Always include a recommendation when you have one.
4. Write the blocker to the `## Blocker` section of the order file.
5. Set `status: needs-input` and preserve the previous status in `previous_status`.
6. Send ntfy notification (best effort — never fail if unreachable).
7. After escalating, return immediately. Let `/x:work` find other orders.
8. When the Captain responds, the decision is final — do not re-ask.
9. Keep the question concise. The Captain is reading on a phone.
10. Two options is ideal. Three is acceptable. More than three means you need to narrow down first.
