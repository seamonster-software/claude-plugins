#!/usr/bin/env bash
# gitea-api.sh — Gitea API wrapper for Sea Monster agents
# Sourced by workflows and claude-runner.sh
# Requires: GITEA_URL, GITEA_TOKEN environment variables

set -euo pipefail

: "${GITEA_URL:?GITEA_URL must be set}"
: "${GITEA_TOKEN:?GITEA_TOKEN must be set}"

GITEA_API="${GITEA_URL}/api/v1"

# --- HTTP helpers ---

gitea_get() {
  local endpoint="$1"
  curl -fsSL \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -H "Accept: application/json" \
    "${GITEA_API}${endpoint}"
}

gitea_post() {
  local endpoint="$1"
  local data="${2:-{}}"
  curl -fsSL -X POST \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "${data}" \
    "${GITEA_API}${endpoint}"
}

gitea_patch() {
  local endpoint="$1"
  local data="${2:-{}}"
  curl -fsSL -X PATCH \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "${data}" \
    "${GITEA_API}${endpoint}"
}

gitea_delete() {
  local endpoint="$1"
  curl -fsSL -X DELETE \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -H "Accept: application/json" \
    "${GITEA_API}${endpoint}"
}

# --- Issues ---

# Create an issue. Args: owner, repo, title, body, [labels_json_array]
gitea_create_issue() {
  local owner="$1" repo="$2" title="$3" body="$4"
  local labels="${5:-[]}"
  local payload
  payload=$(jq -n \
    --arg title "$title" \
    --arg body "$body" \
    --argjson labels "$labels" \
    '{title: $title, body: $body, labels: $labels}')
  gitea_post "/repos/${owner}/${repo}/issues" "$payload"
}

# Add a comment to an issue. Args: owner, repo, issue_number, body
gitea_comment() {
  local owner="$1" repo="$2" issue="$3" body="$4"
  local payload
  payload=$(jq -n --arg body "$body" '{body: $body}')
  gitea_post "/repos/${owner}/${repo}/issues/${issue}/comments" "$payload"
}

# Get issue details. Args: owner, repo, issue_number
gitea_get_issue() {
  local owner="$1" repo="$2" issue="$3"
  gitea_get "/repos/${owner}/${repo}/issues/${issue}"
}

# --- Labels ---

# Add labels to an issue. Args: owner, repo, issue_number, labels_json_array
gitea_add_labels() {
  local owner="$1" repo="$2" issue="$3" labels="$4"
  local payload
  payload=$(jq -n --argjson labels "$labels" '{labels: $labels}')
  gitea_post "/repos/${owner}/${repo}/issues/${issue}/labels" "$payload"
}

# Remove a label from an issue. Args: owner, repo, issue_number, label_id
gitea_remove_label() {
  local owner="$1" repo="$2" issue="$3" label_id="$4"
  gitea_delete "/repos/${owner}/${repo}/issues/${issue}/labels/${label_id}"
}

# Get label ID by name. Args: owner, repo, label_name
# Returns the label ID or empty string if not found
gitea_get_label_id() {
  local owner="$1" repo="$2" name="$3"
  gitea_get "/repos/${owner}/${repo}/labels?limit=50" | \
    jq -r --arg name "$name" '.[] | select(.name == $name) | .id'
}

# --- Pull Requests ---

# Create a PR. Args: owner, repo, title, body, head_branch, base_branch
gitea_create_pr() {
  local owner="$1" repo="$2" title="$3" body="$4" head="$5" base="${6:-main}"
  local payload
  payload=$(jq -n \
    --arg title "$title" \
    --arg body "$body" \
    --arg head "$head" \
    --arg base "$base" \
    '{title: $title, body: $body, head: $head, base: $base}')
  gitea_post "/repos/${owner}/${repo}/pulls" "$payload"
}

# Add a review comment to a PR. Args: owner, repo, pr_number, body
gitea_review_pr() {
  local owner="$1" repo="$2" pr="$3" body="$4"
  local payload
  payload=$(jq -n --arg body "$body" '{body: $body, event: "COMMENT"}')
  gitea_post "/repos/${owner}/${repo}/pulls/${pr}/reviews" "$payload"
}

# Approve a PR. Args: owner, repo, pr_number, body
gitea_approve_pr() {
  local owner="$1" repo="$2" pr="$3" body="${4:-Approved}"
  local payload
  payload=$(jq -n --arg body "$body" '{body: $body, event: "APPROVED"}')
  gitea_post "/repos/${owner}/${repo}/pulls/${pr}/reviews" "$payload"
}

# Merge a PR. Args: owner, repo, pr_number, [merge_style]
gitea_merge_pr() {
  local owner="$1" repo="$2" pr="$3" style="${4:-merge}"
  local payload
  payload=$(jq -n --arg style "$style" '{Do: $style}')
  gitea_post "/repos/${owner}/${repo}/pulls/${pr}/merge" "$payload"
}

# --- Repos ---

# Create a repo in an org. Args: org, repo_name, description
gitea_create_repo() {
  local org="$1" name="$2" description="${3:-}"
  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg desc "$description" \
    '{name: $name, description: $desc, auto_init: true, default_branch: "main"}')
  gitea_post "/orgs/${org}/repos" "$payload"
}

# --- Milestones ---

# Create a milestone. Args: owner, repo, title, description, [due_date]
gitea_create_milestone() {
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
  gitea_post "/repos/${owner}/${repo}/milestones" "$payload"
}

# --- Utility ---

# Check if Gitea is reachable
gitea_health() {
  curl -fsSL -o /dev/null -w '%{http_code}' "${GITEA_URL}/api/v1/version" 2>/dev/null
}
