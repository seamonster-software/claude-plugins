---
description: Dashboard — read all .bridge/orders/ files, group by status, show stats, interactively respond to blockers. The Captain's status view.
---

# /x:voyage — Orders Dashboard

Read all `.bridge/orders/*.md` files, parse their YAML frontmatter, group by
status, display as a dashboard, and let the Captain respond to any blocked
orders interactively.

No GitHub API calls. No `gh` CLI. Pure file operations.

## What to Do

### Step 1: Verify the Bridge Exists

Check that `.bridge/orders/` exists in the current project. If it does not,
tell the Captain to run `/x:init` first.

```bash
if [[ ! -d ".bridge/orders" ]]; then
  echo "No .bridge/orders/ directory found. Run /x:init to set up the bridge."
  exit 1
fi
```

### Step 2: Read All Order Files

Read every `.md` file in `.bridge/orders/` (excluding `.gitkeep`). For each
file, parse the YAML frontmatter between `---` delimiters to extract:

- `id` — order number (e.g. `001`)
- `title` — what the order is about
- `status` — current state in the pipeline
- `priority` — `p0`, `p1`, `p2`
- `branch` — working branch (if assigned)
- `created` — date the order was filed
- `assigned` — whether an agent is actively working on it

Use this approach to parse frontmatter:

```bash
ORDER_FILE=".bridge/orders/001-build-auth.md"
CONTENT=$(cat "$ORDER_FILE")

# Extract frontmatter (between --- delimiters)
FRONTMATTER=$(echo "$CONTENT" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')

# Parse individual fields
ID=$(echo "$FRONTMATTER" | grep '^id:' | sed 's/id: *//')
TITLE=$(echo "$FRONTMATTER" | grep '^title:' | sed 's/title: *//')
STATUS=$(echo "$FRONTMATTER" | grep '^status:' | sed 's/status: *//')
PRIORITY=$(echo "$FRONTMATTER" | grep '^priority:' | sed 's/priority: *//')
BRANCH=$(echo "$FRONTMATTER" | grep '^branch:' | sed 's/branch: *//')
CREATED=$(echo "$FRONTMATTER" | grep '^created:' | sed 's/created: *//')
ASSIGNED=$(echo "$FRONTMATTER" | grep '^assigned:' | sed 's/assigned: *//')
```

Also count archived orders if `.bridge/archive/` exists — just for the stats
summary, no need to parse their full content.

### Step 3: Group Orders by Status

Group all orders into these categories, in display order:

1. **Needs Input** — `status: needs-input` (Captain must act)
2. **Deploy Ready** — `status: deploy-ready` (ready to ship)
3. **Review** — `status: review` (PR waiting for review)
4. **Building** — `status: building` (agents working)
5. **Planning** — `status: planning` (design or breakdown in progress)
6. **Research** — `status: research` (investigation in progress)
7. **Approved** — `status: approved` (queued for Orchestrator)
8. **Proposed** — `status: proposed` (awaiting Captain approval)

Omit any category that has zero orders.

Sort within each group:
- By priority: `p0` first, then `p1`, then `p2`
- By order ID (ascending) as tiebreaker

### Step 4: Format the Dashboard

Display the dashboard in this format:

```
## Voyage — Orders Dashboard

### Needs Input (2) — action required
  #003  Database choice needed                p1    blocked 2d    [has blocker details]
  #007  Auth strategy                         p2    blocked 4h    [has blocker details]

### Deploy Ready (1) — ship it
  #002  Landing page                          p1    branch: order-002-landing

### Review (1) — PR open
  #005  Auth middleware                        p1    branch: order-005-auth

### Building (2) — agents working
  #001  Build authentication module            p1    branch: order-001-auth    active
  #004  API rate limiting                      p2    branch: order-004-rate    active

### Approved (1) — queued for routing
  #006  Course platform                        p2    filed 3d ago

### Proposed (1) — awaiting approval
  #008  URL shortener SaaS                     p2    filed 1d ago

---

### Summary
  8 active orders, 3 archived
  2 need your input (action required)
  1 deploy ready
  1 in review
  2 building
  1 approved, 1 proposed
  Priorities: 0 p0, 4 p1, 4 p2
```

For each order line, show:
- `#ID` — zero-padded order number
- `Title` — order title (truncate to ~40 chars if needed for readability)
- `Priority` — p0, p1, p2
- Context info depending on status:
  - `needs-input`: how long it has been blocked (compute from `created` date or use file modification time)
  - `building`/`review`/`deploy-ready`: branch name if set
  - `building`: show `active` if `assigned: active`
  - `approved`/`proposed`: how long ago it was filed

### Step 5: Handle Blocked Orders (Interactive)

If there are orders with `status: needs-input`, this is the most important part
of the dashboard. After displaying the dashboard, offer to resolve blockers.

**For each `needs-input` order:**

1. Extract the content of the `## Blocker` section from the order file.
   The blocker section is everything between `## Blocker` and the next `##`
   heading (or end of file).

2. Display the blocker details:
   ```
   --- Blocker on #003: Database choice needed ---

   Question from Builder:
   Should we use PostgreSQL or SQLite for the initial build?

   Option A: PostgreSQL
   - Production-ready from day one
   - Handles concurrent writes well
   - More complex setup

   Option B: SQLite
   - Simpler, zero configuration
   - Good for prototyping
   - May need migration later

   Recommendation: PostgreSQL — avoids migration pain.

   ---
   ```

3. Use AskUserQuestion to ask the Captain for a response:

   > "Respond to this blocker? (Type your decision, or 'skip' to leave it blocked)"

4. If the Captain responds (anything other than "skip"):
   - **Append** the Captain's response to the `## Blocker` section in the order
     file. Format it clearly:
     ```
     **Captain's Response ({today's date}):**
     {Captain's response text}
     ```
   - **Update the status** in the YAML frontmatter from `needs-input` back to
     the appropriate previous status. Determine this by reading the order file's
     context:
     - If the `## Plan` section has content → set status to `building`
     - If the `## Design` section has content but `## Plan` does not → set status to `planning`
     - If the `## Research` section has content but `## Design` does not → set status to `planning`
     - If none of the above sections have content → set status to `approved`
     (This heuristic recovers the right pipeline stage based on what work has
     already been done on the order.)
   - **Clear** the `assigned` field if it was set (so `/x:work` can re-dispatch).
   - Report: "Blocker resolved on #003 — status set to building."

5. If the Captain says "skip", move on to the next blocker (or end).

Repeat for every `needs-input` order. Process them in priority order (p0 first).

### Step 6: Summary Stats

At the bottom of the dashboard, show:

- Total active orders (in `.bridge/orders/`)
- Total archived orders (in `.bridge/archive/`)
- Count by status
- Count by priority
- How many need Captain input (highlight this)
- How many are deploy-ready (highlight this)

If there are no orders at all:

```
## Voyage — Orders Dashboard

No orders found. File your first order with /x:order.
```

## Notes

- **Phone-friendly output.** Keep lines short and scannable — the Captain reads
  this on a phone via ntfy or small terminal.
- **Needs-input orders always show first.** They are the only thing that blocks
  the autonomous loop. Everything else is progressing on its own.
- **No GitHub API calls.** All data comes from `.bridge/orders/*.md` files.
- **Blocker section parsing.** Extract everything between `## Blocker` and the
  next `##` heading. If the section is empty (just whitespace), note that no
  blocker details were provided by the agent.
- **Status recovery heuristic.** When unblocking an order, the heuristic
  checks which sections have content to determine where the order was in the
  pipeline. This works because agents append to their designated section as
  they work (Scout writes to `## Research`, Architect to `## Design`, Planner
  to `## Plan`).
- **Idempotent display.** Running `/x:voyage` multiple times shows the current
  state. Only the interactive blocker response modifies files.
- **Archived orders.** Only count archived orders for stats — do not display
  their details on the dashboard. The dashboard is for active work.
- **Order file modifications.** When updating an order file (appending to
  blocker section, changing status), preserve all existing content. Only modify
  the specific fields/sections being updated. Never overwrite the whole file.
