---
description: Create the .bridge/ directory, configure ntfy topic, and test connectivity. One-time setup for Sea Monster in the current project.
---

# /x:init — Set Up Sea Monster

This is the one-time onboarding command for a project. It creates the `.bridge/` directory (the file-based state machine), configures ntfy for notifications, and verifies connectivity.

Run this in the root of the project repo where you want the crew to work.

## Prerequisites

Before running this command, the user needs:
- A project repo (any git host — GitHub, GitLab, Codeberg, local)
- `curl` installed (for ntfy connectivity test)
- An ntfy topic URL (optional but strongly recommended)

No `gh` CLI, no GitHub API, no specific git host required.

## Step 1: Check Current Directory

Verify we're in a git repository:

```bash
if git rev-parse --is-inside-work-tree &>/dev/null; then
  PROJECT_ROOT=$(git rev-parse --show-toplevel)
  echo "Project root: $PROJECT_ROOT"
else
  echo "Not inside a git repository. Run /x:init from a project repo."
  exit 1
fi
```

## Step 2: Create .bridge/ Directory Structure

Create the bridge directory and subdirectories. Skip any that already exist (idempotent).

```bash
mkdir -p "$PROJECT_ROOT/.bridge/orders"
mkdir -p "$PROJECT_ROOT/.bridge/archive"
```

If `.bridge/config.yml` already exists, read it and show the current configuration to the user. Do NOT overwrite it — the user may have customized settings.

If `.bridge/config.yml` does not exist, create it in Step 4 after gathering configuration.

**Important:** Do NOT add `.bridge/` to `.gitignore`. Order history belongs in git — it's the audit trail.

## Step 3: Gather Configuration

Ask the user for their ntfy topic (use AskUserQuestion):

> **ntfy topic URL?**
>
> This is where Sea Monster sends notifications — order completions, blocker alerts, status updates.
> You can also send orders and respond to blockers from your phone via ntfy.
>
> Examples:
> - Self-hosted: `https://ntfy.example.com/seamonster`
> - Free hosted: `https://ntfy.sh/your-unique-topic-name`
>
> Enter your ntfy topic URL, or leave blank to skip (you can configure it later in `.bridge/config.yml`):

Store the response as `NTFY_TOPIC`.

If the user skips (blank response), set `NTFY_TOPIC` to empty. ntfy is strongly recommended but not required — the system degrades gracefully without it.

## Step 4: Write config.yml

If `.bridge/config.yml` already exists, ask the user if they want to update the ntfy topic. If yes, update only the `ntfy.topic` value. If no, leave it as-is.

If `.bridge/config.yml` does not exist, create it:

```yaml
# Sea Monster Bridge Configuration
# Created by /x:init

ntfy:
  topic: "<NTFY_TOPIC or empty string>"
  # Set to true to disable all ntfy notifications
  disabled: false

# Project settings
project:
  # Next order number (auto-incremented by /x:order)
  next_order_id: 1
```

Replace `<NTFY_TOPIC or empty string>` with the actual value from Step 3. If the user skipped, write an empty string: `topic: ""`

## Step 5: Test ntfy Connectivity

If the user provided an ntfy topic, test it:

```bash
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  -d "Sea Monster initialized! Your crew is ready." \
  -H "Title: Sea Monster" \
  -H "Tags: pirate_flag" \
  "$NTFY_TOPIC" 2>/dev/null)

if [[ "$RESPONSE" == "200" ]]; then
  echo "ntfy test notification sent successfully."
else
  echo "ntfy test failed (HTTP $RESPONSE). Check your topic URL."
fi
```

If the test fails, warn the user but do NOT abort. They can fix the URL later in `.bridge/config.yml`. The crew works fine without ntfy — they just won't get push notifications.

If the user skipped ntfy configuration, skip this step entirely.

## Step 6: Add .bridge/orders/.gitkeep

Ensure the empty directories are tracked by git:

```bash
touch "$PROJECT_ROOT/.bridge/orders/.gitkeep"
touch "$PROJECT_ROOT/.bridge/archive/.gitkeep"
```

## Step 7: Print Summary

If ntfy was configured and tested successfully:
```
Sea Monster initialized!

  Bridge:  .bridge/
  Orders:  .bridge/orders/
  Archive: .bridge/archive/
  Config:  .bridge/config.yml
  ntfy:    <topic URL> (connected)

Next steps:
  1. /x:order — file your first order
  2. /loop 5m /x:work — start the autonomous loop
  3. /x:voyage — check status anytime
```

If ntfy was configured but test failed:
```
Sea Monster initialized!

  Bridge:  .bridge/
  Orders:  .bridge/orders/
  Archive: .bridge/archive/
  Config:  .bridge/config.yml
  ntfy:    <topic URL> (connection failed — check URL)

Next steps:
  1. Fix ntfy URL in .bridge/config.yml
  2. /x:order — file your first order
  3. /loop 5m /x:work — start the autonomous loop
  4. /x:voyage — check status anytime
```

If ntfy was skipped:
```
Sea Monster initialized!

  Bridge:  .bridge/
  Orders:  .bridge/orders/
  Archive: .bridge/archive/
  Config:  .bridge/config.yml
  ntfy:    not configured

Next steps:
  1. (Optional) Add ntfy topic to .bridge/config.yml for push notifications
  2. /x:order — file your first order
  3. /loop 5m /x:work — start the autonomous loop
  4. /x:voyage — check status anytime
```

## Important

- **Idempotent:** Safe to run multiple times. Directories are created with `mkdir -p`. Config is only written if it doesn't already exist (or if the user explicitly asks to update it).
- **No GitHub API calls:** This command does not use `gh`, does not create repos, does not push workflows, does not create labels.
- **No `.gitignore` changes:** The `.bridge/` directory is tracked in git. Order files are the audit trail.
- **ntfy is optional:** The crew works without it. Captain uses `/x:voyage` to check status and respond to blockers interactively instead of via phone.
- **curl is the only external dependency** (and only for the ntfy test). Everything else is plain file operations.
