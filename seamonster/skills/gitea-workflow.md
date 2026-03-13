---
name: "Gitea Workflow"
description: >
  Complete reference for Gitea API usage via lib/gitea-api.sh.
  Covers issue lifecycle, label management, PR workflow, milestones,
  and comment patterns for agent updates.
---

# Gitea Workflow Reference

All Sea Monster agents interact with Gitea through `./lib/gitea-api.sh`.
Source this file at the start of any script that touches Gitea.

```bash
source ./lib/gitea-api.sh
```

Required environment variables (set by the runner):
- `GITEA_URL` — base URL of the Gitea server (e.g., `https://git.seamonster.software`)
- `GITEA_TOKEN` — API token with repo and issue permissions
- `SEAMONSTER_ORG` — the Gitea organization name (default: `seamonster`)

## Issue Lifecycle

### Create an Issue

```bash
# Simple issue
gitea_create_issue "$SEAMONSTER_ORG" "project-alpha" \
  "Build authentication module" \
  "## Requirements\n\n- JWT tokens\n- Refresh token rotation\n- Rate limiting"

# Issue with labels (pass label IDs as JSON array)
label_id=$(gitea_get_label_id "$SEAMONSTER_ORG" "project-alpha" "team/build")
gitea_create_issue "$SEAMONSTER_ORG" "project-alpha" \
  "Build authentication module" \
  "## Requirements\n\n- JWT tokens" \
  "[$label_id]"
```

### Read an Issue

```bash
issue_json=$(gitea_get_issue "$SEAMONSTER_ORG" "project-alpha" "47")
echo "$issue_json" | jq -r '.title'
echo "$issue_json" | jq -r '.body'
echo "$issue_json" | jq -r '.labels[].name'
echo "$issue_json" | jq -r '.state'
echo "$issue_json" | jq -r '.milestone.title // "none"'
```

### Comment on an Issue

Every agent action should be posted as a comment. This is the audit trail.

```bash
gitea_comment "$SEAMONSTER_ORG" "project-alpha" "47" \
  "**Builder** — starting work.

Branch: \`issue-47-auth-module\`
Plan:
1. Create token service
2. Add middleware
3. Write tests"
```

### Close an Issue

```bash
gitea_patch "/repos/${SEAMONSTER_ORG}/project-alpha/issues/47" \
  '{"state": "closed"}'
```

### List Open Issues

```bash
# All open issues in a repo
gitea_get "/repos/${SEAMONSTER_ORG}/project-alpha/issues?state=open&limit=50"

# Filter by label
gitea_get "/repos/${SEAMONSTER_ORG}/project-alpha/issues?state=open&labels=build-ready&limit=50"

# Filter by milestone
gitea_get "/repos/${SEAMONSTER_ORG}/project-alpha/issues?state=open&milestone=3&limit=50"
```

### List Issues Across All Repos

```bash
# Get all repos in the org
repos=$(gitea_get "/orgs/${SEAMONSTER_ORG}/repos" | jq -r '.[].name')

for repo in $repos; do
  issues=$(gitea_get "/repos/${SEAMONSTER_ORG}/${repo}/issues?state=open&limit=50")
  count=$(echo "$issues" | jq 'length')
  if [[ "$count" -gt 0 ]]; then
    echo "=== ${repo} (${count} open) ==="
    echo "$issues" | jq -r '.[] | "  #\(.number) [\(.labels | map(.name) | join(", "))] \(.title)"'
  fi
done
```

## Label Management

### Scoped Labels

Sea Monster uses scoped labels (prefix/value) for structured metadata:

```
team/scout       team/build       team/ops         team/growth
priority/p0      priority/p1      priority/p2
size/small       size/medium      size/large
status/blocked   status/waiting   status/active
type/proposal    type/feature     type/bug         type/deploy
```

### Add a Label

```bash
label_id=$(gitea_get_label_id "$SEAMONSTER_ORG" "project-alpha" "build-ready")
gitea_add_labels "$SEAMONSTER_ORG" "project-alpha" "47" "[$label_id]"
```

### Remove a Label

```bash
label_id=$(gitea_get_label_id "$SEAMONSTER_ORG" "project-alpha" "needs-input")
gitea_remove_label "$SEAMONSTER_ORG" "project-alpha" "47" "$label_id"
```

### Add Multiple Labels

```bash
label1=$(gitea_get_label_id "$SEAMONSTER_ORG" "project-alpha" "team/build")
label2=$(gitea_get_label_id "$SEAMONSTER_ORG" "project-alpha" "priority/p1")
gitea_add_labels "$SEAMONSTER_ORG" "project-alpha" "47" "[$label1, $label2]"
```

### State Transition Labels

These labels drive the issue state machine. Adding them triggers Gitea Actions:

| Label | Triggers | Agent Spawned |
|---|---|---|
| `approved` | `on-approved.yml` | Architect + Planner |
| `build-ready` | `on-build-ready.yml` | Builder |
| `needs-input` | `on-needs-input.yml` | ntfy to Captain |
| `deploy-ready` | `on-deploy-ready.yml` | Deployer |
| `incident` | `on-incident.yml` | Post-mortem analysis |

## Pull Request Workflow

### Create a PR

```bash
gitea_create_pr "$SEAMONSTER_ORG" "project-alpha" \
  "feat: add authentication module (#47)" \
  "## Summary\nImplements JWT authentication.\n\n## Changes\n- Token service\n- Auth middleware\n\nCloses #47" \
  "issue-47-auth-module" \
  "main"
```

### Review a PR

```bash
# Comment review (neutral)
gitea_review_pr "$SEAMONSTER_ORG" "project-alpha" "12" \
  "Reviewed the auth module. Found 2 issues — see inline comments."

# Approve
gitea_approve_pr "$SEAMONSTER_ORG" "project-alpha" "12" \
  "Clean implementation, tests pass, no security issues found. Approved."
```

### Merge a PR

```bash
# Default merge commit
gitea_merge_pr "$SEAMONSTER_ORG" "project-alpha" "12"

# Squash merge
gitea_merge_pr "$SEAMONSTER_ORG" "project-alpha" "12" "squash"

# Rebase merge
gitea_merge_pr "$SEAMONSTER_ORG" "project-alpha" "12" "rebase"
```

### Get PR Details

```bash
pr_json=$(gitea_get "/repos/${SEAMONSTER_ORG}/project-alpha/pulls/12")
echo "$pr_json" | jq -r '.title'
echo "$pr_json" | jq -r '.merged'
echo "$pr_json" | jq -r '.head.ref'  # source branch
echo "$pr_json" | jq -r '.base.ref'  # target branch
```

### List Open PRs

```bash
gitea_get "/repos/${SEAMONSTER_ORG}/project-alpha/pulls?state=open&limit=50"
```

## Milestones

### Create a Milestone

```bash
# Without due date
gitea_create_milestone "$SEAMONSTER_ORG" "project-alpha" \
  "Phase 1: MVP" \
  "Core features: auth, API, basic UI"

# With due date (ISO 8601)
gitea_create_milestone "$SEAMONSTER_ORG" "project-alpha" \
  "Phase 1: MVP" \
  "Core features: auth, API, basic UI" \
  "2026-04-01T00:00:00Z"
```

### List Milestones

```bash
gitea_get "/repos/${SEAMONSTER_ORG}/project-alpha/milestones" | \
  jq -r '.[] | "\(.title): \(.open_issues) open, \(.closed_issues) closed"'
```

### Assign Issue to Milestone

```bash
# Get milestone ID first
milestone_id=$(gitea_get "/repos/${SEAMONSTER_ORG}/project-alpha/milestones" | \
  jq -r '.[] | select(.title == "Phase 1: MVP") | .id')

gitea_patch "/repos/${SEAMONSTER_ORG}/project-alpha/issues/47" \
  "{\"milestone\": $milestone_id}"
```

## Repository Operations

### Create a Repo

```bash
gitea_create_repo "$SEAMONSTER_ORG" "project-beta" \
  "An e-commerce platform built by the Sea Monster crew"
```

### Check Gitea Health

```bash
status=$(gitea_health)
if [[ "$status" == "200" ]]; then
  echo "Gitea is healthy"
else
  echo "Gitea returned HTTP ${status}"
fi
```

## Comment Patterns for Agents

Every agent comment follows a consistent format for readability:

```
**{Role}** — {action summary}

{details}
```

Examples:

```
**Builder** — starting work on issue #47.

Branch: `issue-47-auth-module`
```

```
**Reviewer** — changes requested on PR #12.

2 critical issues found. See review comments.
```

```
**Deployer** — deployed to production.

URL: https://project-alpha.seamonster.software
Health check: passed
```

```
**Orchestrator** — routing to Builder.

This is a build task. Creating issue and assigning to build team.
```

## Issue Dependencies

Gitea supports issue dependencies (blocks/blocked-by). Use the API:

```bash
# Issue 48 is blocked by issue 47
gitea_post "/repos/${SEAMONSTER_ORG}/project-alpha/issues/48/dependencies" \
  "{\"dependency_id\": 47}"
```

## Pagination

All list endpoints support pagination:

```bash
# Page 2, 50 items per page
gitea_get "/repos/${SEAMONSTER_ORG}/project-alpha/issues?state=open&page=2&limit=50"
```

Default limit is typically 20. Always set `limit=50` for list queries to reduce
the number of API calls.

## Error Handling

The gitea-api.sh functions use `curl -fsSL` which exits non-zero on HTTP errors.
Always check return codes:

```bash
if ! issue_json=$(gitea_get_issue "$SEAMONSTER_ORG" "$REPO" "$ISSUE"); then
  echo "Failed to fetch issue #${ISSUE}" >&2
  exit 1
fi
```
