---
name: "crew-status"
description: "Show status of all active work — issues by state, recent activity, blocked items."
---

# /crew-status

Show the current status of all active work across the Sea Monster fleet.

## What to Do

Query all repos in the org and present a summary grouped by state.

### Step 1: Gather Data

Gather all open issues and PRs across the org:

```bash
source ./lib/git-api.sh
ORG="${SEAMONSTER_ORG:-seamonster}"
repos=$(sm_list_repos "$ORG" | jq -r '.[].name')
for repo in $repos; do
  sm_list_issues "$ORG" "$repo"
  sm_list_prs "$ORG" "$repo"
done
```

### Step 2: Present Summary

Group issues into these categories and display as a clear report:

**Blocked (needs Captain input):**
Issues with `needs-input` or `status/blocked` label. These are the highest
priority — something is waiting on the Captain.

**Building (in progress):**
Issues with `status/active` or `build-ready` label, or with associated open PRs.

**Reviewing (PRs open):**
Open pull requests awaiting Reviewer review.

**Deploy Ready:**
Issues with `deploy-ready` label, waiting for Deployer.

**Queued (waiting to start):**
Issues with `status/waiting` or `approved` label.

**Proposals (pending approval):**
Issues with `type/proposal` label awaiting Captain review.

### Step 3: Format Output

Present the report in this format:

```
## Crew Status

### Blocked — needs your input (2)
- project-alpha #47: Auth module — JWT vs sessions? (3h ago)
- project-beta #12: Database choice needed (1d ago)

### Building (3)
- project-alpha #48: User registration API (Builder, 2h ago)
- project-alpha #49: Email service (Builder, 1h ago)
- project-gamma #3: Landing page (Builder, 4h ago)

### Reviewing (1)
- project-alpha PR #15: Auth middleware (Reviewer, 30m ago)

### Deploy Ready (1)
- project-gamma #2: Static site build (Deployer, waiting)

### Queued (2)
- project-alpha #50: Admin dashboard (approved, not started)
- project-beta #8: Payment integration (approved, not started)

### Proposals (1)
- bridge #22: URL shortener SaaS (Scout, pending approval)
```

### Step 4: Highlight Issues

Call out anything that needs attention:
- Issues blocked for more than 24 hours
- PRs open for more than 48 hours without review
- Build tasks that have been active for more than 8 hours without a progress comment
- Deploy-ready issues that have not been deployed

## Notes

- Exclude the `bridge` repo from build/deploy status (it is the coordination repo)
- Sort each category by last update time (most recent first)
- Show relative time ("3h ago", "1d ago") not absolute timestamps
- If there is no work in a category, omit that section
