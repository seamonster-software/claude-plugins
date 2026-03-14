---
description: Spawn a specific crew member, optionally on a specific order. Usage: /x:spawn <agent> [order-number]
argument-hint: Orchestrator|Builder|Reviewer|Deployer|Scout|Analyst|Proposal Writer|Architect|Planner|QA|Security|Monitor|Sysadmin
---

# /x:spawn <agent> [order-number]

Directly spawn a specific crew member. Bypasses the Orchestrator's routing —
use when you know exactly which agent you need.

## Arguments

- `agent` (required) — the crew member to spawn (case-insensitive):
  - `orchestrator`
  - `builder`
  - `reviewer`
  - `deployer`
  - `scout`
  - `analyst`
  - `proposal-writer`
  - `architect`
  - `planner`
  - `qa`
  - `security`
  - `monitor`
  - `sysadmin`

- `order-number` (optional) — an order ID from `.bridge/orders/`. When provided,
  the agent receives the full order context. When omitted, the agent starts
  with no specific order assignment.

## What to Do

### Step 1: Parse and Validate Arguments

Parse the command arguments. The first argument is the agent name, the second
(optional) is the order number.

If the agent name is not recognized, list the available crew members and stop:

```
Available crew members:
  orchestrator, builder, reviewer, deployer, scout, analyst,
  proposal-writer, architect, planner, qa, security, monitor, sysadmin
```

### Step 2: Map Agent Name to Subagent Type

Map the input to the correct subagent type. Agent names are case-insensitive
and accept hyphenated forms:

| Input | Subagent Type |
|---|---|
| `orchestrator` | x:Orchestrator |
| `builder` | x:Builder |
| `reviewer` | x:Reviewer |
| `deployer` | x:Deployer |
| `scout` | x:Scout |
| `analyst` | x:Analyst |
| `proposal-writer` | x:Proposal Writer |
| `architect` | x:Architect |
| `planner` | x:Planner |
| `qa` | x:QA |
| `security` | x:Security |
| `monitor` | x:Monitor |
| `sysadmin` | x:Sysadmin |

### Step 3: Load Order Context (if order number provided)

If an order number was provided, find the matching order file in `.bridge/orders/`.
Order files are named with a zero-padded ID prefix (e.g., `001-build-auth.md`,
`012-landing-page.md`).

```bash
BRIDGE_DIR=".bridge"
ORDERS_DIR="${BRIDGE_DIR}/orders"

# Find the order file by ID prefix
ORDER_FILE=$(ls "${ORDERS_DIR}/"* 2>/dev/null | while read f; do
  basename "$f"
done | grep "^$(printf '%03d' ${ORDER_NUMBER})-" | head -1)

if [ -z "$ORDER_FILE" ]; then
  echo "No order file found for order #${ORDER_NUMBER}"
  exit 1
fi

ORDER_PATH="${ORDERS_DIR}/${ORDER_FILE}"
```

Read the order file and extract its frontmatter:

```bash
CONTENT=$(cat "$ORDER_PATH")
FRONTMATTER=$(echo "$CONTENT" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')
STATUS=$(echo "$FRONTMATTER" | grep '^status:' | sed 's/status: *//')
TITLE=$(echo "$FRONTMATTER" | grep '^title:' | sed 's/title: *//')
PRIORITY=$(echo "$FRONTMATTER" | grep '^priority:' | sed 's/priority: *//')
```

If `.bridge/orders/` does not exist or is empty, report:

> "No bridge found. Run `/x:init` to set up the bridge, or omit the order number to spawn without order context."

### Step 4: Update Order Assignment (if order provided)

Before spawning, mark the order as actively assigned to prevent duplicate
dispatch by `/x:work`:

Update the order file's frontmatter to set `assigned: active`.

### Step 5: Spawn the Agent

Use the Agent tool with the mapped `subagent_type` to spawn the crew member.

**When an order is provided**, pass the order context to the agent:

```
You are the {Agent} working on order #{id}: {title}

Read the order file at {order_file_path} for full context — including any
research, design, and plan sections that previous agents wrote.

Work according to your role. When done:
- Update the order file status as appropriate for your role
- Set assigned: "" in the frontmatter
- If blocked, write your question in the ## Blocker section, set status to
  "needs-input", set assigned to ""
```

**When no order is provided**, give the agent a general prompt:

```
You are the {Agent}. No specific order was assigned.

Work according to your role in the current project context. Check the project's
CLAUDE.md for conventions and the .bridge/orders/ directory for any relevant
context.
```

### Step 6: Confirm

After spawning, report what was dispatched:

**With order:**
```
Spawned Builder for order #001 — Build authentication module
Order file: .bridge/orders/001-build-auth.md
Status: building | Priority: p1
```

**Without order:**
```
Spawned Builder in current project context.
No specific order assigned — agent will work according to its role.
```

## Examples

```
/x:spawn builder
  Spawns Builder with no specific order — works on current project context

/x:spawn builder 5
  Spawns Builder to work on order #005

/x:spawn reviewer 12
  Spawns Reviewer to review the PR for order #012

/x:spawn architect
  Spawns Architect with no specific order

/x:spawn proposal-writer 3
  Spawns Proposal Writer to work on order #003
```

## Notes

- This command bypasses the Orchestrator's routing. Use it when you know
  exactly which agent you need.
- The spawned agent inherits the project's CLAUDE.md conventions.
- All 13 crew members are available as subagent types.
- When an order is provided, the agent is responsible for updating the order
  file's `status` and `assigned` fields when it finishes.
- No GitHub API or `gh` CLI calls. All state lives in `.bridge/orders/` files.
- For automated dispatch based on order status, use `/x:work` instead.
