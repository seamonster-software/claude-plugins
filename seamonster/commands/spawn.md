---
name: "spawn"
description: "Explicitly spawn a specific crew member for a project. Usage: /spawn <crew-member> <project>"
args: "<crew-member> <project>"
---

# /spawn <crew-member> <project>

Explicitly spawn a specific crew member to work on a project. Bypasses the
Orchestrator's routing — use when you know exactly which agent you need.

## Arguments

- `crew-member` — the crew member to spawn (case-insensitive). Accepts both
  character names and role names:
  - `builder`
  - `reviewer`
  - `deployer`
  - `orchestrator`
  - `sysadmin`
  - `architect`
  - `planner`
  - `qa`
  - `security`
  - `monitor`
  - `scout`
  - `proposal-writer`
  - `analyst`

- `project` — the Gitea repo name (e.g., `project-alpha`, `_hub`)

## What to Do

### Step 1: Validate the Arguments

Parse the command arguments. If the crew member name is not recognized, list
available crew members. If the project does not exist in Gitea, report the error.

```bash
source /opt/seamonster/lib/gitea-api.sh

# Verify the repo exists
if ! gitea_get "/repos/${SEAMONSTER_ORG}/${PROJECT}" > /dev/null 2>&1; then
  echo "Error: repo '${PROJECT}' not found in org '${SEAMONSTER_ORG}'"
  echo "Available repos:"
  gitea_get "/orgs/${SEAMONSTER_ORG}/repos" | jq -r '.[].name' | sort
  exit 1
fi
```

### Step 2: Map to Agent

Map the crew member argument to the correct agent name:

| Input | Agent |
|---|---|
| `builder` | Builder |
| `reviewer` | Reviewer |
| `deployer` | Deployer |

### Step 3: Spawn the Agent

Use the Agent tool to spawn the selected crew member as a subagent. Provide
the project context:

```
Spawning Builder for project: {project}

The agent will work in the context of the {project} repository. It will:
1. Check for open issues labeled build-ready
2. Pick the highest priority unblocked issue
3. Follow the standard issue → branch → build → PR flow
```

If no specific issue is mentioned, the spawned agent should check for open
issues in the project that match its role:
- Builder: issues with `build-ready` or `team/build` labels
- Reviewer: open PRs awaiting review
- Deployer: issues with `deploy-ready` label

### Step 4: Confirm

After spawning, report what was dispatched:

```
Spawned Builder for project-alpha.
Working on: issue #47 — Build authentication module
Branch: issue-47-auth-module
```

## Examples

```
/spawn builder project-alpha
→ Spawns Builder to work on project-alpha's highest priority build task

/spawn reviewer project-alpha
→ Spawns Reviewer to review open PRs in project-alpha

/spawn deployer project-alpha
→ Spawns Deployer to deploy pending deploy-ready issues in project-alpha
```

## Notes

- This command bypasses the Orchestrator's routing. Use it when you know
  exactly which agent and project you want.
- The spawned agent inherits the project's CLAUDE.md conventions.
- If the project has no matching work (e.g., no build-ready issues for
  Builder), the agent reports this and exits.
- Only core crew members (Builder, Reviewer, Deployer) are available
  as interactive subagents. Other crew members are dispatched via Gitea
  issues for autonomous execution.
