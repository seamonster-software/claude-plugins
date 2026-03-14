---
description: Poll .bridge/orders/ for actionable work, check ntfy for inbound messages, dispatch agents. The Captain's autonomous loop engine.
---

# /x:work — Work the Queue

Poll `.bridge/orders/` for actionable orders and check ntfy for inbound messages. Dispatch the right crew member for each actionable order. This is the engine behind `/loop 5m /x:work`.

## What to Do

### Step 1: Locate the Bridge

Find the `.bridge/` directory in the current project:

```bash
BRIDGE_DIR=".bridge"
ORDERS_DIR="${BRIDGE_DIR}/orders"
ARCHIVE_DIR="${BRIDGE_DIR}/archive"
CONFIG_FILE="${BRIDGE_DIR}/config.yml"
```

If `.bridge/` does not exist, stop and tell the Captain:

> "No bridge found. Run `/x:init` to set up the bridge first."

### Step 2: Load Configuration

Read `.bridge/config.yml` for ntfy settings:

```yaml
# Expected config.yml structure:
ntfy:
  topic: https://ntfy.sh/seamonster-XXXX   # or self-hosted URL
  enabled: true
```

Parse the config file. If ntfy is not configured or the file is missing, continue without ntfy — the file-based state machine works without it.

### Step 3: Check ntfy for Inbound Messages

If ntfy is enabled, poll for recent messages since the last check. Use the ntfy JSON polling API:

```bash
# Poll for messages since last check (use since=10m for loop cycles)
curl -s "${NTFY_TOPIC}/json?poll=1&since=10m" 2>/dev/null
```

Process each inbound message by type:

**New orders** — message does NOT start with "re:" or "reply:" and is NOT "voyage" or "status":
1. Determine the next order ID by scanning existing files in `.bridge/orders/` and `.bridge/archive/`
2. Create a new order file in `.bridge/orders/` with:
   - `status: approved` (Captain-filed orders skip proposal)
   - `priority: p2` (default, Captain can adjust)
   - `created: {today's date}`
   - The message body as the order description
3. Report: "New order received via ntfy: #{id} — {title}"

**Blocker replies** — message starts with "re:" or "reply:" followed by an order number (e.g., "re: 5 use JWT"):
1. Find the matching order file by ID
2. Append the Captain's response to the `## Blocker` section
3. Change status from `needs-input` back to the previous status (check the order file's context to determine the right status — typically `building`, `planning`, or `research`)
4. Report: "Blocker resolved on order #{id} — resuming"

**Status requests** — message is "voyage" or "status" (case-insensitive):
1. Build a summary of all orders by status (same as `/x:voyage` output)
2. Send the summary back via ntfy:
   ```bash
   curl -s -d "${SUMMARY}" "${NTFY_TOPIC}" 2>/dev/null || true
   ```
3. Report: "Status sent to Captain via ntfy"

If ntfy polling fails (network error, not configured), log it and continue. ntfy is best-effort.

### Step 4: Scan Orders

Read all `.md` files in `.bridge/orders/`. For each file, parse the YAML frontmatter to extract:

- `id` — the order number
- `title` — what the order is about
- `status` — current state in the pipeline
- `priority` — p0, p1, p2
- `branch` — the working branch (if assigned)
- `assigned` — agent currently working on it (if any)

Use this approach to parse frontmatter:

```bash
# Read the file
ORDER_FILE=".bridge/orders/001-build-auth.md"
CONTENT=$(cat "$ORDER_FILE")

# Extract frontmatter (between --- delimiters)
FRONTMATTER=$(echo "$CONTENT" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')

# Parse individual fields
STATUS=$(echo "$FRONTMATTER" | grep '^status:' | sed 's/status: *//')
PRIORITY=$(echo "$FRONTMATTER" | grep '^priority:' | sed 's/priority: *//')
ID=$(echo "$FRONTMATTER" | grep '^id:' | sed 's/id: *//')
TITLE=$(echo "$FRONTMATTER" | grep '^title:' | sed 's/title: *//')
ASSIGNED=$(echo "$FRONTMATTER" | grep '^assigned:' | sed 's/assigned: *//')
```

### Step 5: Build the Work Queue

Sort orders into actionable categories based on their `status` field. Priority order for dispatch:

**1. Deploy Ready** — `status: deploy-ready`
- Agent: **x:Deployer**
- Ship first, always.

**2. Review** — `status: review`
- Agent: **x:Reviewer**
- Review PRs before starting new builds.

**3. Building** — `status: building`
- Agent: **x:Builder**
- Only dispatch if the order does NOT have `assigned: active` (prevents duplicate dispatch).
- Sort by priority (p0 > p1 > p2), then by order ID.

**4. Planning** — `status: planning`
- Agent: **x:Planner** (or **x:Architect** if the order needs design decisions)
- Check the order body: if it mentions architecture, system design, or stack decisions, use x:Architect. Otherwise use x:Planner.

**5. Research** — `status: research`
- Agent: **x:Scout** (or **x:Analyst** if the order asks for evaluation/comparison)
- Check the order body: if it asks to evaluate, compare, or analyze, use x:Analyst. Otherwise use x:Scout.

**6. Approved** — `status: approved`
- Agent: **x:Orchestrator**
- The Orchestrator will read the order, determine the right pipeline depth, and update the status.

**Skip these statuses:**
- `needs-input` — waiting for Captain. Show in the queue display but do not dispatch.
- `proposed` — not yet approved. Show but do not dispatch.
- `done` — should be in archive, not orders. Ignore.
- `rejected` — should be in archive. Ignore.

### Step 6: Prevent Duplicate Dispatching

Before dispatching an agent for an order, check the `assigned` field in the frontmatter:

- If `assigned: active` — skip. An agent is already working on this order.
- If `assigned:` is empty or missing — safe to dispatch.

When dispatching, update the order file's frontmatter to set `assigned: active` BEFORE spawning the agent. This prevents the next `/x:work` cycle from double-dispatching.

```yaml
---
id: 001
title: Build authentication module
status: building
priority: p1
branch: order-001-auth
assigned: active
---
```

When an agent finishes (succeeds or fails), it should clear the `assigned` field and update the `status` accordingly.

### Step 7: Present the Queue

Show the Captain what was found:

```
## Work Queue

### Deploy Ready (1)
  #002  Landing page deployment                p1    → Deployer

### Review (1)
  #005  Auth middleware PR                      p1    → Reviewer

### Building (2)
  #001  Build authentication module             p1    → Builder
  #004  API rate limiting                       p2    → Builder

### Approved (1)
  #006  Course platform                         p2    → Orchestrator

### Blocked — needs Captain input (1)
  #003  Database choice needed                  p1    waiting 2d

### Proposed — awaiting approval (1)
  #007  URL shortener SaaS                      p2    submitted 1d ago

Ready to dispatch 5 orders.
```

If there is nothing actionable, say:

> "No actionable work in the queue. File orders with `/x:order` or send them via ntfy."

### Step 8: Get Confirmation

Use AskUserQuestion to ask the Captain:

> "Ready to dispatch N orders. Work all, pick specific numbers (e.g. #1,#3), or skip?"

Options:
- **all** — dispatch every actionable order
- **#1,#3,#5** — dispatch specific orders by ID
- **skip** — show the queue but do not dispatch

If there is only 1 actionable order, skip confirmation and dispatch it directly.

If running inside `/loop`, skip confirmation and dispatch all actionable orders automatically.

### Step 9: Dispatch Agents

For each order to be dispatched:

1. Set `assigned: active` in the order file's frontmatter
2. Spawn the appropriate agent as a subagent using the Agent tool

**Dispatch context for each agent type:**

**x:Orchestrator** (for `approved` orders):
```
You are the Orchestrator working on order #{id}: {title}

Read the order file at {order_file_path}. Determine the right pipeline based on complexity:
- Clear, scoped task → set status to "building"
- Needs breakdown → set status to "planning"
- Needs design decisions → set status to "planning" (Architect will handle)
- Unknown domain → set status to "research"

Update the order file's status field. Add your routing decision to the order body.
When done, set assigned: "" in the frontmatter.
```

**x:Builder** (for `building` orders):
```
You are the Builder working on order #{id}: {title}

Read the order file at {order_file_path} for full context — including any research,
design, and plan sections that previous agents wrote.

1. Create branch: order-{id}-{short-description}
2. Update the order file: set branch field to your branch name
3. Build the feature/fix described in the order
4. Commit with conventional commits
5. Open a PR back to main
6. Update the order file: set status to "review", set assigned to ""
7. If blocked, write your question in the ## Blocker section, set status to "needs-input", set assigned to ""
```

**x:Reviewer** (for `review` orders):
```
You are the Reviewer. Review the PR for order #{id}: {title}

Read the order file at {order_file_path} to understand the context.
Find the PR on the branch specified in the order file.
Review the diff — check for bugs, security issues, edge cases, code quality.
You are READ-ONLY — do not modify source files.

If approved: merge the PR, set status to "deploy-ready" (or "done" if no deployment needed), set assigned to ""
If changes needed: post review comments, set status to "building", set assigned to ""
Write your review summary in the ## Review section of the order file.
```

**x:Deployer** (for `deploy-ready` orders):
```
You are the Deployer working on order #{id}: {title}

Read the order file at {order_file_path} for deploy context.
Deploy the changes described. Follow the project's deploy conventions.
When done: set status to "done", set assigned to "", move the order file to .bridge/archive/
```

**x:Scout** (for `research` orders needing exploration):
```
You are the Scout researching order #{id}: {title}

Read the order file at {order_file_path}.
Research the topic — competitors, libraries, market landscape, technical options.
Write your findings in the ## Research section of the order file.
When done: set status to "planning", set assigned to ""
If blocked, write your question in ## Blocker, set status to "needs-input", set assigned to ""
```

**x:Analyst** (for `research` orders needing evaluation):
```
You are the Analyst evaluating order #{id}: {title}

Read the order file at {order_file_path}.
Evaluate the options, compare trade-offs, assess viability.
Write your analysis in the ## Research section of the order file.
When done: set status to "planning", set assigned to ""
```

**x:Architect** (for `planning` orders needing design):
```
You are the Architect designing order #{id}: {title}

Read the order file at {order_file_path}.
Design the system — components, boundaries, stack decisions, interfaces.
Write your design in the ## Design section of the order file.
When done: set status to "planning" (for Planner to break down), set assigned to ""
If design is simple enough to skip planning: set status to "building", set assigned to ""
```

**x:Planner** (for `planning` orders needing task breakdown):
```
You are the Planner breaking down order #{id}: {title}

Read the order file at {order_file_path}.
Break the work into phases, milestones, and dependencies.
Write your plan in the ## Plan section of the order file.
When done: set status to "building", set assigned to ""
```

### Step 10: Report

After dispatching, summarize what happened:

```
## Dispatched

- Deployer  → order #002 (Landing page deployment)
- Reviewer  → order #005 (Auth middleware PR)
- Builder   → order #001 (Build authentication module)
- Builder   → order #004 (API rate limiting)

4 agents working. Run /x:voyage to check progress.
```

If ntfy is enabled, send a summary notification:

```bash
curl -s -d "Work cycle: dispatched 4 orders" "${NTFY_TOPIC}" 2>/dev/null || true
```

## Dispatch Rules

1. **One agent per order.** Never spawn two agents for the same order.
2. **Respect priority order.** Deploy first, then review, then build, then plan, then research, then route.
3. **Check assigned field.** If `assigned: active`, skip — an agent is already on it.
4. **Mark before dispatch.** Set `assigned: active` in the order file BEFORE spawning the agent. This prevents race conditions with the next `/loop` cycle.
5. **Parallel is fine.** Independent orders can be dispatched as parallel subagents. Use multiple Agent tool calls in a single response.
6. **Cap concurrent work.** Do not dispatch more than 3 agents at once unless the Captain explicitly asks for more. Session context and rate limits matter.
7. **Show blocked orders.** Always display `needs-input` orders so the Captain can respond, but never auto-dispatch agents for blocked work.
8. **No gh CLI.** All state lives in `.bridge/orders/` files. Read and write files directly. No GitHub API calls.
9. **ntfy is best-effort.** If ntfy fails, log it and continue. The file-based state machine is the source of truth.
10. **Agents own cleanup.** Each dispatched agent is responsible for clearing `assigned` and updating `status` when it finishes.

## Notes

- This command is designed to run inside `/loop 5m /x:work` for autonomous operation. It also works as a one-shot command.
- When running in `/loop`, skip the confirmation prompt and dispatch all actionable orders automatically.
- The spawned agents should use the Agent tool with the appropriate `subagent_type` (x:Builder, x:Reviewer, x:Deployer, x:Orchestrator, x:Scout, x:Analyst, x:Architect, x:Planner).
- Order files accumulate context as they move through the pipeline. Each agent reads what previous agents wrote and appends its contribution. Never overwrite existing sections.
- If no actionable work is found and no ntfy messages arrived, say: "No actionable work in the queue. File orders with `/x:order` or send them via ntfy."
- The `assigned` field prevents duplicate dispatching across `/loop` cycles. If an agent crashes without clearing it, the Captain can manually edit the order file to reset it.
