---
name: "voyage"
description: "Project overview — all projects, their phase, health, milestone completion, recent deploys, active builds."
---

# /voyage

High-level overview of all projects in the fleet. Shows project phase,
health, milestone progress, recent deployments, and active builds.

## What to Do

### Step 1: Gather Project Data

Gather project data using the appropriate API:

**Gitea:**
```bash
source ./lib/gitea-api.sh
ORG="${SEAMONSTER_ORG:-seamonster}"
repos=$(gitea_get "/orgs/${ORG}/repos" | jq -r '.[] | select(.name != "bridge") | .name')

for repo in $repos; do
  # Get milestones with completion percentages
  milestones=$(gitea_get "/repos/${ORG}/${repo}/milestones?state=all&limit=50")

  # Get open issue count
  repo_info=$(gitea_get "/repos/${ORG}/${repo}")
  open_issues=$(echo "$repo_info" | jq '.open_issues_count')

  # Get recent closed issues (last 7 days for deploy/activity detection)
  recent_closed=$(gitea_get "/repos/${ORG}/${repo}/issues?state=closed&limit=10&type=issues")

  # Get open PRs
  open_prs=$(gitea_get "/repos/${ORG}/${repo}/pulls?state=open&limit=10")

  # Get recent merged PRs
  merged_prs=$(gitea_get "/repos/${ORG}/${repo}/pulls?state=closed&limit=10" | \
    jq '[.[] | select(.merged != null)]')
done
```

### Step 2: Determine Project Phase

Infer the project phase from its milestones and issue labels:

| Phase | Indicators |
|---|---|
| **Planning** | Has open milestones, no `status/active` issues, recent architecture/planning issues |
| **Building** | Has `status/active` or `build-ready` issues, open PRs |
| **Reviewing** | Has open PRs but no `build-ready` issues |
| **Deploying** | Has `deploy-ready` issues |
| **Live** | Has deployed services, Monitor monitoring active |
| **Growth** | Has `team/growth` issues, live service running |
| **Idle** | No recent activity (7+ days), no open issues |

### Step 3: Calculate Health

Project health is a simple traffic light:

- **Healthy**: No blocked issues, milestones on track, no recent failures
- **Attention**: Has blocked issues or stale PRs (>48h without review)
- **Unhealthy**: Multiple blockers, missed milestones, deployment failures

### Step 4: Format Output

```
## Voyage — Fleet Overview

### project-alpha — Building
  Health: healthy
  Milestones:
    Wave 1: Foundation    ████████████████████ 100% (5/5 closed)
    Wave 2: Services      ████████████░░░░░░░░  60% (3/5 closed)
    Wave 3: Integration   ░░░░░░░░░░░░░░░░░░░░   0% (0/4 closed, blocked by Wave 2)
  Active: 2 issues building, 1 PR open
  Last deploy: none yet

### project-beta — Planning
  Health: attention — 1 issue blocked for 2 days
  Milestones:
    Phase 1: MVP          ░░░░░░░░░░░░░░░░░░░░   0% (0/8 closed)
  Active: 0 building, 0 PRs
  Last deploy: none yet

### project-gamma — Live
  Health: healthy
  Milestones:
    Launch                ████████████████████ 100% (3/3 closed)
  Active: 0 building, 0 PRs
  Last deploy: 2 days ago — https://project-gamma.seamonster.software

### Summary
  3 projects total
  1 live, 1 building, 1 planning
  6 milestones across fleet (2 complete, 3 in progress, 1 not started)
  1 project needs attention
```

### Step 5: Milestone Progress Bars

Generate visual progress bars from milestone data:

```bash
# Calculate percentage
open=$(echo "$milestone" | jq '.open_issues')
closed=$(echo "$milestone" | jq '.closed_issues')
total=$((open + closed))
if [[ $total -gt 0 ]]; then
  pct=$((closed * 100 / total))
else
  pct=0
fi

# Generate bar (20 chars wide)
filled=$((pct / 5))
empty=$((20 - filled))
bar=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null) ; printf '░%.0s' $(seq 1 $empty 2>/dev/null))
echo "    ${milestone_title}  ${bar} ${pct}% (${closed}/${total} closed)"
```

## Notes

- Exclude the `bridge` repo from the project list (it is the coordination repo,
  not a project)
- Sort projects by phase: Unhealthy first, then Building, Reviewing,
  Deploying, Planning, Live, Idle
- For "Last deploy" — check for recently closed issues with `deploy-ready`
  label or merged PRs that triggered deploy workflows
- If a project has no milestones, show the issue counts instead
- Show the project URL if it has been deployed
- Keep the output scannable — the Captain reads this on a phone
