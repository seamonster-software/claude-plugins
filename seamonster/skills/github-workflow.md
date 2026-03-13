---
name: "GitHub Workflow"
description: >
  Complete reference for GitHub API usage via lib/github-api.sh.
  Covers issue lifecycle, label management, PR workflow, milestones,
  and comment patterns for agent updates. Use this when working with
  GitHub (Lite/Solo tiers) instead of gitea-workflow.
---

# GitHub Workflow Reference

All Sea Monster agents interact with GitHub through `./lib/github-api.sh`.
Source this file at the start of any script that touches GitHub.

```bash
source ./lib/github-api.sh
```

Required environment variables:
- `GITHUB_TOKEN` — API token (automatic in GitHub Actions, or a PAT)
- `SEAMONSTER_ORG` — the GitHub organization or user name

## Key Differences from Gitea

| Feature | Gitea | GitHub |
|---------|-------|--------|
| Token env var | `GITEA_TOKEN` | `GITHUB_TOKEN` (automatic in Actions) |
| Org-level labels | Yes | No (per-repo only) |
| Issue dependencies | Built-in | Not native (use "blocked by #N" in body) |
| Merge check | `.merged == true` | `.merged_at != null` |
| Label operations | By ID | By name |
| Time tracking | Built-in | Not native |

## Issue Lifecycle

### Create an Issue

```bash
# Simple issue
github_create_issue "$SEAMONSTER_ORG" "project-alpha" \
  "Build authentication module" \
  "## Requirements\n\n- JWT tokens\n- Refresh token rotation\n- Rate limiting"

# Issue with labels (GitHub uses label names, not IDs)
github_create_issue "$SEAMONSTER_ORG" "project-alpha" \
  "Build authentication module" \
  "## Requirements\n\n- JWT tokens" \
  '["team/build", "priority/p1"]'
```

### Read an Issue

```bash
issue_json=$(github_get_issue "$SEAMONSTER_ORG" "project-alpha" "47")
echo "$issue_json" | jq -r '.title'
echo "$issue_json" | jq -r '.body'
echo "$issue_json" | jq -r '.labels[].name'
echo "$issue_json" | jq -r '.state'
echo "$issue_json" | jq -r '.milestone.title // "none"'
```

### Comment on an Issue

Every agent action should be posted as a comment. This is the audit trail.

```bash
github_comment "$SEAMONSTER_ORG" "project-alpha" "47" \
  "**Builder** — starting work.

Branch: \`issue-47-auth-module\`
Plan:
1. Create token service
2. Add middleware
3. Write tests"
```

### Close an Issue

```bash
github_patch "/repos/${SEAMONSTER_ORG}/project-alpha/issues/47" \
  '{"state": "closed"}'
```

### List Open Issues

```bash
# All open issues in a repo
github_get "/repos/${SEAMONSTER_ORG}/project-alpha/issues?state=open&per_page=50"

# Filter by label
github_get "/repos/${SEAMONSTER_ORG}/project-alpha/issues?state=open&labels=build-ready&per_page=50"

# Filter by milestone
github_get "/repos/${SEAMONSTER_ORG}/project-alpha/issues?state=open&milestone=3&per_page=50"
```

### List Issues Across All Repos

```bash
# Get all repos in the org
repos=$(github_list_repos "$SEAMONSTER_ORG" | jq -r '.[].name')

for repo in $repos; do
  issues=$(github_get "/repos/${SEAMONSTER_ORG}/${repo}/issues?state=open&per_page=50")
  count=$(echo "$issues" | jq 'length')
  if [[ "$count" -gt 0 ]]; then
    echo "=== ${repo} (${count} open) ==="
    echo "$issues" | jq -r '.[] | "  #\(.number) [\(.labels | map(.name) | join(", "))] \(.title)"'
  fi
done
```

## Label Management

### Add Labels

```bash
# GitHub uses label names directly (not IDs like Gitea)
github_add_labels "$SEAMONSTER_ORG" "project-alpha" "47" '["build-ready"]'

# Multiple labels
github_add_labels "$SEAMONSTER_ORG" "project-alpha" "47" '["team/build", "priority/p1"]'
```

### Remove a Label

```bash
github_remove_label "$SEAMONSTER_ORG" "project-alpha" "47" "needs-input"
```

### Create Labels (per-repo)

GitHub does not support org-level labels. Create them on each repo:

```bash
github_create_label "$SEAMONSTER_ORG" "project-alpha" "build-ready" "1d76db" "Ready for Builder"
github_create_label "$SEAMONSTER_ORG" "project-alpha" "needs-input" "e4e669" "Agent blocked — Captain decision needed"
github_create_label "$SEAMONSTER_ORG" "project-alpha" "deploy-ready" "5319e7" "Ready for Deployer"
```

### State Transition Labels

These labels drive the issue state machine. Adding them triggers GitHub Actions:

| Label | Triggers | Agent Spawned |
|---|---|---|
| `approved` | `on-approved.yml` | Architect + Planner |
| `build-ready` | `on-build-ready.yml` | Builder |
| `needs-input` | `on-needs-input.yml` | ntfy to Captain |
| `deploy-ready` | `on-deploy-ready.yml` | Deployer |

## Pull Request Workflow

### Create a PR

```bash
github_create_pr "$SEAMONSTER_ORG" "project-alpha" \
  "feat: add authentication module (#47)" \
  "## Summary\nImplements JWT authentication.\n\nCloses #47" \
  "issue-47-auth-module" \
  "main"
```

### Review a PR

```bash
# Comment review
github_review_pr "$SEAMONSTER_ORG" "project-alpha" "12" \
  "Reviewed the auth module. Found 2 issues — see inline comments."

# Approve
github_approve_pr "$SEAMONSTER_ORG" "project-alpha" "12" \
  "Clean implementation. Approved."
```

### Merge a PR

```bash
# Default merge commit
github_merge_pr "$SEAMONSTER_ORG" "project-alpha" "12"

# Squash merge
github_merge_pr "$SEAMONSTER_ORG" "project-alpha" "12" "squash"
```

## Milestones

```bash
# Create
github_create_milestone "$SEAMONSTER_ORG" "project-alpha" \
  "Phase 1: MVP" \
  "Core features: auth, API, basic UI"

# List
github_get "/repos/${SEAMONSTER_ORG}/project-alpha/milestones" | \
  jq -r '.[] | "\(.title): \(.open_issues) open, \(.closed_issues) closed"'
```

## Repository Operations

```bash
# Create a repo
github_create_repo "$SEAMONSTER_ORG" "project-beta" \
  "An e-commerce platform built by the Sea Monster crew"

# List repos
github_list_repos "$SEAMONSTER_ORG" | jq -r '.[].name'

# Check API health
status=$(github_health)
echo "GitHub API: HTTP ${status}"
```

## Comment Patterns for Agents

Same format as Gitea — every agent comment follows:

```
**{Role}** — {action summary}

{details}
```

## Pagination

GitHub uses `per_page` (max 100) and `page` parameters:

```bash
github_get "/repos/${SEAMONSTER_ORG}/project-alpha/issues?state=open&page=2&per_page=100"
```

## Error Handling

The github-api.sh functions use `curl -fsSL` which exits non-zero on HTTP errors.
Always check return codes:

```bash
if ! issue_json=$(github_get_issue "$SEAMONSTER_ORG" "$REPO" "$ISSUE"); then
  echo "Failed to fetch issue #${ISSUE}" >&2
  exit 1
fi
```

## Secrets Configuration

Set these as repository or organization secrets in GitHub Settings:

| Secret | Value | Notes |
|--------|-------|-------|
| `GITHUB_TOKEN` | (automatic) | Provided by GitHub Actions |
| `NTFY_URL` | e.g. `https://ntfy.sh` | All tiers |
| `NTFY_TOKEN` | ntfy auth token | Optional for public ntfy.sh |
| `SEAMONSTER_ORG` | The org name | All tiers |
| `SEAMONSTER_DOMAIN` | e.g. `example.com` | For deploy workflows |
