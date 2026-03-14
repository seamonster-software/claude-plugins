#!/usr/bin/env bash
# github-api.sh — GitHub API wrapper for Sea Monster agents
# Sourced by workflows and claude-runner.sh
# Requires: GITHUB_TOKEN environment variable (automatic in GitHub Actions)
# Uses curl for portability (no gh CLI dependency)

set -euo pipefail

# GITHUB_TOKEN is required but may be set by git-api.sh from gh CLI auth
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: GITHUB_TOKEN not set. Set it directly or authenticate gh CLI (gh auth login)." >&2
  exit 1
fi

GITHUB_API="https://api.github.com"

# --- HTTP helpers ---

github_get() {
  local endpoint="$1"
  curl -fsSL \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "${GITHUB_API}${endpoint}"
}

github_post() {
  local endpoint="$1"
  local data="${2:-{}}"
  curl -fsSL -X POST \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -d "${data}" \
    "${GITHUB_API}${endpoint}"
}

github_patch() {
  local endpoint="$1"
  local data="${2:-{}}"
  curl -fsSL -X PATCH \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -d "${data}" \
    "${GITHUB_API}${endpoint}"
}

github_delete() {
  local endpoint="$1"
  curl -fsSL -X DELETE \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "${GITHUB_API}${endpoint}"
}

# --- Issues ---

# Create an issue. Args: owner, repo, title, body, [labels_json_array]
github_create_issue() {
  local owner="$1" repo="$2" title="$3" body="$4"
  local labels="${5:-[]}"
  local payload
  payload=$(jq -n \
    --arg title "$title" \
    --arg body "$body" \
    --argjson labels "$labels" \
    '{title: $title, body: $body, labels: $labels}')
  github_post "/repos/${owner}/${repo}/issues" "$payload"
}

# Add a comment to an issue. Args: owner, repo, issue_number, body
github_comment() {
  local owner="$1" repo="$2" issue="$3" body="$4"
  local payload
  payload=$(jq -n --arg body "$body" '{body: $body}')
  github_post "/repos/${owner}/${repo}/issues/${issue}/comments" "$payload"
}

# Get issue details. Args: owner, repo, issue_number
github_get_issue() {
  local owner="$1" repo="$2" issue="$3"
  github_get "/repos/${owner}/${repo}/issues/${issue}"
}

# --- Labels ---

# Add labels to an issue. Args: owner, repo, issue_number, labels_json_array
# Note: GitHub expects label names (strings), not IDs
github_add_labels() {
  local owner="$1" repo="$2" issue="$3" labels="$4"
  local payload
  payload=$(jq -n --argjson labels "$labels" '{labels: $labels}')
  github_post "/repos/${owner}/${repo}/issues/${issue}/labels" "$payload"
}

# Remove a label from an issue. Args: owner, repo, issue_number, label_name
github_remove_label() {
  local owner="$1" repo="$2" issue="$3" label_name="$4"
  local encoded
  encoded=$(printf '%s' "$label_name" | jq -sRr @uri)
  github_delete "/repos/${owner}/${repo}/issues/${issue}/labels/${encoded}"
}

# Get label by name. Args: owner, repo, label_name
# Returns the label name (GitHub uses names, not IDs, for label operations)
github_get_label_id() {
  local owner="$1" repo="$2" name="$3"
  # GitHub uses label names directly, but return name for API compatibility
  local encoded
  encoded=$(printf '%s' "$name" | jq -sRr @uri)
  github_get "/repos/${owner}/${repo}/labels/${encoded}" 2>/dev/null | jq -r '.name // empty'
}

# Create a label. Args: owner, repo, name, color, [description]
github_create_label() {
  local owner="$1" repo="$2" name="$3" color="$4" description="${5:-}"
  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg color "$color" \
    --arg desc "$description" \
    '{name: $name, color: $color, description: $desc}')
  github_post "/repos/${owner}/${repo}/labels" "$payload"
}

# --- Pull Requests ---

# Create a PR. Args: owner, repo, title, body, head_branch, base_branch
github_create_pr() {
  local owner="$1" repo="$2" title="$3" body="$4" head="$5" base="${6:-main}"
  local payload
  payload=$(jq -n \
    --arg title "$title" \
    --arg body "$body" \
    --arg head "$head" \
    --arg base "$base" \
    '{title: $title, body: $body, head: $head, base: $base}')
  github_post "/repos/${owner}/${repo}/pulls" "$payload"
}

# Add a review to a PR. Args: owner, repo, pr_number, body, [event]
# event: COMMENT, APPROVE, REQUEST_CHANGES
github_review_pr() {
  local owner="$1" repo="$2" pr="$3" body="$4" event="${5:-COMMENT}"
  local payload
  payload=$(jq -n --arg body "$body" --arg event "$event" '{body: $body, event: $event}')
  github_post "/repos/${owner}/${repo}/pulls/${pr}/reviews" "$payload"
}

# Approve a PR. Args: owner, repo, pr_number, body
github_approve_pr() {
  local owner="$1" repo="$2" pr="$3" body="${4:-Approved}"
  github_review_pr "$owner" "$repo" "$pr" "$body" "APPROVE"
}

# Merge a PR. Args: owner, repo, pr_number, [merge_method]
# merge_method: merge, squash, rebase
github_merge_pr() {
  local owner="$1" repo="$2" pr="$3" method="${4:-merge}"
  local payload
  payload=$(jq -n --arg method "$method" '{merge_method: $method}')
  github_post "/repos/${owner}/${repo}/pulls/${pr}/merge" "$(echo "$payload" | jq -c .)" 2>/dev/null || \
    # PUT method for GitHub merge
    curl -fsSL -X PUT \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Content-Type: application/json" \
      -H "Accept: application/vnd.github+json" \
      -d "$payload" \
      "${GITHUB_API}/repos/${owner}/${repo}/pulls/${pr}/merge"
}

# --- Repos ---

# Create a repo in an org. Args: org, repo_name, description
github_create_repo() {
  local org="$1" name="$2" description="${3:-}"
  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg desc "$description" \
    '{name: $name, description: $desc, auto_init: true, default_branch: "main"}')
  github_post "/orgs/${org}/repos" "$payload"
}

# List repos in an org. Args: org
github_list_repos() {
  local org="$1"
  github_get "/orgs/${org}/repos?per_page=100&type=sources&sort=updated"
}

# --- Milestones ---

# Create a milestone. Args: owner, repo, title, description, [due_date]
github_create_milestone() {
  local owner="$1" repo="$2" title="$3" description="${4:-}"
  local due_date="${5:-}"
  local payload
  if [[ -n "$due_date" ]]; then
    payload=$(jq -n \
      --arg title "$title" \
      --arg desc "$description" \
      --arg due "$due_date" \
      '{title: $title, description: $desc, due_on: $due}')
  else
    payload=$(jq -n \
      --arg title "$title" \
      --arg desc "$description" \
      '{title: $title, description: $desc}')
  fi
  github_post "/repos/${owner}/${repo}/milestones" "$payload"
}

# --- Utility ---

# Check if GitHub API is reachable
github_health() {
  curl -fsSL -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    "${GITHUB_API}/rate_limit" 2>/dev/null
}
