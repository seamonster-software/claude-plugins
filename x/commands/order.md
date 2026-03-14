---
description: File a new order. Prompts for title and description, auto-increments the order ID, creates .bridge/orders/NNN-slug.md with YAML frontmatter and section scaffolding.
---

# /x:order — File a New Order

Create a new order file in `.bridge/orders/`. This is how the Captain files work
for the crew — no GitHub API, no issue tracker, just a markdown file with YAML
frontmatter that drives the state machine.

## What to Do

### Step 1: Verify the Bridge Exists

Check that `.bridge/orders/` exists in the current project. If it does not, tell
the Captain to run `/x:init` first.

```bash
if [[ ! -d ".bridge/orders" ]]; then
  echo "No .bridge/orders/ directory found. Run /x:init to set up the bridge."
  exit 1
fi
```

### Step 2: Get Order Details from the Captain

Use AskUserQuestion to prompt for the order title:

> "What's the order? (short title, e.g. 'Build authentication module')"

Then use AskUserQuestion to prompt for the description:

> "Describe what needs to be done. (This becomes the order body — can be brief or detailed.)"

Optionally ask for priority:

> "Priority? p0 (critical), p1 (high), p2 (normal — default)"

If the Captain does not specify priority, default to `p2`.

### Step 3: Generate the Next Order ID

Scan `.bridge/orders/` for the highest existing order ID and increment by 1.

```bash
# Find the highest existing order ID
HIGHEST=$(ls .bridge/orders/*.md 2>/dev/null \
  | sed 's|.*/||' \
  | grep -oP '^\d+' \
  | sort -n \
  | tail -1)

# If no orders exist yet, start at 1
if [[ -z "$HIGHEST" ]]; then
  NEXT_ID=1
else
  NEXT_ID=$((HIGHEST + 1))
fi

# Zero-pad to 3 digits
ORDER_ID=$(printf "%03d" "$NEXT_ID")
```

Also check `.bridge/archive/` if it exists, to avoid ID collisions with
completed orders:

```bash
if [[ -d ".bridge/archive" ]]; then
  HIGHEST_ARCHIVE=$(ls .bridge/archive/*.md 2>/dev/null \
    | sed 's|.*/||' \
    | grep -oP '^\d+' \
    | sort -n \
    | tail -1)
  if [[ -n "$HIGHEST_ARCHIVE" && "$HIGHEST_ARCHIVE" -ge "$NEXT_ID" ]]; then
    NEXT_ID=$((HIGHEST_ARCHIVE + 1))
    ORDER_ID=$(printf "%03d" "$NEXT_ID")
  fi
fi
```

### Step 4: Generate the Slug

Convert the title to a URL-friendly slug:

```bash
SLUG=$(echo "$TITLE" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9 ]//g' \
  | sed 's/  */ /g' \
  | sed 's/ /-/g' \
  | sed 's/^-//;s/-$//' \
  | cut -c1-50)
```

The slug should be:
- Lowercase
- Alphanumeric and hyphens only
- Spaces converted to hyphens
- Consecutive hyphens collapsed
- Truncated to 50 characters max
- No leading or trailing hyphens

### Step 5: Create the Order File

Write the order file to `.bridge/orders/{ORDER_ID}-{SLUG}.md`:

```bash
FILENAME=".bridge/orders/${ORDER_ID}-${SLUG}.md"
TODAY=$(date +%Y-%m-%d)

cat > "$FILENAME" << EOF
---
id: ${ORDER_ID}
title: ${TITLE}
status: proposed
priority: ${PRIORITY}
created: ${TODAY}
---

${DESCRIPTION}

## Captain's Notes

## Research

## Design

## Plan

## Blocker

## Review
EOF
```

The frontmatter fields match the format defined in PROJECT.md:

| Field | Value |
|-------|-------|
| `id` | Zero-padded order number (e.g. `001`) |
| `title` | The order title from the Captain |
| `status` | Always `proposed` for new orders |
| `priority` | `p0`, `p1`, or `p2` (default `p2`) |
| `created` | Today's date in `YYYY-MM-DD` format |

New orders do NOT include a `branch` field — that gets added by the Builder
when work begins (e.g. `branch: order-001-auth`).

### Step 6: Confirm

Show the Captain what was created:

```
Order filed.

  .bridge/orders/001-build-auth-module.md
  Status: proposed
  Priority: p2

Next: approve it and run /x:work to dispatch agents.
```

### Step 7: Stage the File

Stage the new order file so it is included in the next commit:

```bash
git add "$FILENAME"
```

Do NOT commit automatically — the Captain may want to review or edit the file
first. Just stage it.

## Examples

```
/x:order
> What's the order? Build authentication module
> Describe what needs to be done. JWT-based auth with refresh tokens. Support email/password login.
> Priority? p1

→ Created .bridge/orders/001-build-auth-module.md (proposed, p1)
```

```
/x:order
> What's the order? Fix billing page crash
> Describe what needs to be done. Users report 500 error on /billing when subscription is expired.
> Priority? p0

→ Created .bridge/orders/002-fix-billing-page-crash.md (proposed, p0)
```

## Notes

- This command uses NO GitHub API calls. It is pure file operations.
- The order file is the single source of truth for this unit of work.
- New orders always start as `proposed`. The Captain approves them (status →
  `approved`), then `/x:work` picks them up and the Orchestrator routes them.
- The Captain can edit the order file directly at any time — add notes, change
  priority, update the description.
- If `.bridge/orders/` does not exist, the Captain needs to run `/x:init` first.
- Order IDs are globally unique across active orders and archived orders.
