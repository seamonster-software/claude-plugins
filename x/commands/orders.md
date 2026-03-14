---
description: List all open issues across all repos, grouped by action needed — blocked, build-ready, in-progress, proposals.
---

# /orders

Show all open orders (issues) across the fleet, grouped by what action is
needed next.

## What to Do

### Step 1: Gather All Open Issues

```bash
source ./lib/git-api.sh
ORG="${SEAMONSTER_ORG:-seamonster}"
repos=$(sm_list_repos "$ORG" | jq -r '.[].name')
for repo in $repos; do
  sm_list_issues "$ORG" "$repo"
done
```

### Step 2: Group by Category

Categorize every open issue into one of these groups:

**Needs Input (Captain must act):**
Issues with `needs-input` label. These are blocking an agent. Show the
question summary and how long it has been waiting.

**Build Ready (queued for Builder):**
Issues with `build-ready` label but not `status/active`. These are approved
and ready to build but no agent has picked them up yet.

**In Progress (agents working):**
Issues with `status/active` label. Show which agent type is working on it
and how long it has been active.

**Proposals Pending (Captain should review):**
Issues with `type/proposal` label. These need Captain approval before they
enter the pipeline.

**Deploy Ready (queued for Deployer):**
Issues with `deploy-ready` label. Ready to ship but not yet deployed.

**Other Open:**
Any open issues that do not match the above categories. May need triage.

### Step 3: Format Output

```
## Orders

### Needs Your Input (2) — action required
  project-alpha #47  Auth: JWT vs sessions?            waiting 3h
  project-beta  #12  Database: Postgres vs SQLite?     waiting 1d

### Build Ready (3) — queued
  project-alpha #50  Admin dashboard                   size/medium  priority/p1
  project-alpha #51  API rate limiting                 size/small   priority/p2
  project-beta  #15  User onboarding flow              size/large   priority/p1

### In Progress (2) — agents working
  project-alpha #48  User registration API             Builder    2h active
  project-gamma #3   Landing page                      Builder    4h active

### Proposals Pending (1) — review when ready
  bridge        #22  URL shortener SaaS                Scout      submitted 2d ago

### Deploy Ready (1) — ship it
  project-gamma #2   Static site build                 reviewed     ready 6h

### Other Open (1) — may need triage
  project-alpha #45  Investigate slow query             no labels
```

### Step 4: Summary Line

End with a one-line summary:

```
Total: 10 open orders. 2 need your input. 3 ready to build. 1 ready to deploy.
```

## Notes

- Sort "Needs Input" by wait time (longest first) — stale blockers surface first
- Sort "Build Ready" by priority label, then by issue number
- Sort "In Progress" by time active (longest first)
- Show the `size/*` and `priority/*` labels for build-ready items to help
  the Captain understand the work queue
- Include the repo name for every issue since this spans multiple repos
- Exclude closed issues entirely
- If a category has no items, omit it from the output
