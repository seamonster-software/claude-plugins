---
name: "Escalation Protocol"
description: >
  When and how to escalate to the Captain. Formatting questions with
  options and trade-offs, label management for blocked issues,
  and moving on to other work while awaiting a response.
---

# Escalation Protocol

Agents never stall silently. When blocked, they escalate with a well-structured
question, then move on to other work.

## When to Escalate

Escalate when:
- A design decision is needed that is not covered by the project's CLAUDE.md or existing issue comments
- Two valid approaches exist and the trade-offs require Captain judgment
- An external dependency is unavailable or broken (third-party API down, service unreachable)
- A security concern requires human review before proceeding
- The issue requirements are ambiguous or contradictory
- Budget, pricing, or business strategy decisions are involved
- You have been working on a problem for more than 15 minutes without progress

Do NOT escalate when:
- The answer is in the project CLAUDE.md, issue comments, or existing code
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

### Step 1: Post the Question

```bash
source ./lib/git-api.sh

sm_comment "$SEAMONSTER_ORG" "$REPO" "$ISSUE_NUMBER" \
  "**${CREW_NAME}** — blocked, need a decision.

**Question:** Should user sessions persist across server restarts?

**Option A: In-memory sessions**
- No Redis dependency, simpler setup
- Users lose sessions on deploy/restart
- Cannot scale to multiple servers

**Option B: Redis-backed sessions**
- Sessions survive restarts
- Required for multi-server scaling
- Adds Redis dependency

**Recommendation:** Redis-backed — deploy restarts would break all user sessions otherwise."
```

### Step 2: Add Labels

```bash
sm_add_labels "$SEAMONSTER_ORG" "$REPO" "$ISSUE_NUMBER" \
  '["status/blocked", "needs-input"]'
```

### Step 3: Move On

Check for other unblocked work:

```bash
# Find other issues assigned to this agent's team that are not blocked
other_issues=$(sm_list_issues "$SEAMONSTER_ORG" "$REPO" | \
  jq '[.[] | select(.labels | map(.name) |
    (contains(["build-ready"]) or contains(["team/build"])) and
    (contains(["status/blocked"]) | not) and
    (contains(["needs-input"]) | not)
  )]')

count=$(echo "$other_issues" | jq 'length')
if [[ "$count" -gt 0 ]]; then
  next_issue=$(echo "$other_issues" | jq -r '.[0].number')
  echo "Moving to issue #${next_issue} while awaiting response on #${ISSUE_NUMBER}"
  # Start working on the next issue
else
  echo "No other unblocked work available. Exiting cleanly."
  # Exit — will be re-triggered when Captain responds
  exit 0
fi
```

## When the Captain Responds

The Captain responds by posting a comment on the issue directly (or via GitHub mobile).

When a response arrives:
1. The `on-needs-input` workflow detects the new comment
2. It removes the `needs-input` label
3. It removes the `status/blocked` label
4. It re-spawns the agent with the decision context

The decision is permanently recorded in the issue timeline.

## Label Reference

| Label | Meaning | Added By | Removed By |
|---|---|---|---|
| `needs-input` | Waiting for Captain's decision | Agent (on escalation) | Workflow (on response) |
| `status/blocked` | Cannot proceed | Agent (on escalation) | Workflow (on response) |
| `status/active` | Currently being worked on | Agent (on start) | Agent (on completion/block) |
| `status/waiting` | Queued, not yet started | Orchestrator (on triage) | Agent (on start) |

## Escalation Priority

Not all escalations are equally urgent. Match the label and comment urgency
to the impact:

| Situation | Priority |
|---|---|
| Service is down in production | `urgent` |
| Security vulnerability found | `urgent` |
| Blocker that halts all build progress | `urgent` |
| Design decision, other work available | `high` |
| Nice-to-have question, low impact | `default` |
| Non-blocking feedback request | `low` |

## Timeout Handling

If a blocked issue receives no response within 48 hours:
- The daily digest mentions it as "still awaiting input"
- After 7 days, the Orchestrator (or dispatch workflow) re-posts the question as a comment
- After 14 days, the issue is flagged in the weekly learnings as "stale blocker"

Agents do not poll for responses. The workflow on `issue_comment` handles
re-triggering automatically.

## Multiple Blockers

If an agent hits multiple blockers in the same session:
- Post each as a separate comment on the relevant issue
- Each blocker gets its own GitHub notification
- Bundle them if they are related (one comment with multiple questions)
- The Captain can respond to them independently and in any order

## Cascading Escalation

Sometimes a question from one agent should be redirected to another:

| Original Agent | Question Type | Redirect To |
|---|---|---|
| Builder | Architecture decision | Architect |
| Builder | Timeline/scope | Planner |
| Deployer | System-level dependency | Sysadmin |
| Any agent | Security concern | Security |
| Any agent | Unclear requirements | Orchestrator → Captain |

When redirecting, the agent comments on the issue tagging the target:

```bash
sm_comment "$SEAMONSTER_ORG" "$REPO" "$ISSUE_NUMBER" \
  "**Builder** — this is an architecture question. Redirecting to Architect.

**Question:** The data model requires either a relational schema (normalized, SQL)
or a document store (denormalized, MongoDB). This decision affects the entire
service layer. Needs Architect's input before I proceed."
```

## Rules

1. Never stall silently. If you are blocked, escalate.
2. Always provide options with trade-offs. Never ask open-ended questions.
3. Always include a recommendation when you have one.
4. Post the question on the issue as a comment (permanent record and GitHub notification).
5. Add both `needs-input` and `status/blocked` labels.
6. After escalating, check for other unblocked work. Do not idle.
7. When the Captain responds, the decision is final — do not re-ask.
8. Keep the question concise. The Captain is reading on a phone.
9. Include the project name and issue number in the comment.
10. Two options is ideal. Three is acceptable. More than three means you need to narrow down first.
