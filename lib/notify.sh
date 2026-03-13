#!/usr/bin/env bash
# notify.sh — ntfy notification helpers for Sea Monster agents
# Sourced by workflows and claude-runner.sh
# Requires: NTFY_URL environment variable
# Optional: NTFY_TOKEN for authenticated servers

set -euo pipefail

: "${NTFY_URL:?NTFY_URL must be set}"

# Default topic prefix — all Sea Monster topics live under this
NTFY_PREFIX="${NTFY_PREFIX:-seamonster}"

# --- Core send function ---

# Send a notification. All other functions are convenience wrappers.
# Args: topic, title, message, [priority], [tags], [actions_json]
ntfy_send() {
  local topic="$1"
  local title="$2"
  local message="$3"
  local priority="${4:-default}"
  local tags="${5:-}"
  local actions="${6:-}"

  local -a curl_args=(
    -fsSL -X POST
    -H "Title: ${title}"
    -H "Priority: ${priority}"
  )

  if [[ -n "${NTFY_TOKEN:-}" ]]; then
    curl_args+=(-H "Authorization: Bearer ${NTFY_TOKEN}")
  fi

  if [[ -n "$tags" ]]; then
    curl_args+=(-H "Tags: ${tags}")
  fi

  if [[ -n "$actions" ]]; then
    curl_args+=(-H "Actions: ${actions}")
  fi

  curl_args+=(-d "$message" "${NTFY_URL}/${NTFY_PREFIX}-${topic}")

  curl "${curl_args[@]}"
}

# --- Convenience functions ---

# Urgent notification — blockers, failures, decisions needed NOW
# Args: title, message, [actions_json]
ntfy_urgent() {
  local title="$1" message="$2" actions="${3:-}"
  ntfy_send "urgent" "$title" "$message" "urgent" "rotating_light" "$actions"
}

# Build progress — PRs ready, build status
# Args: title, message, [actions_json]
ntfy_build() {
  local title="$1" message="$2" actions="${3:-}"
  ntfy_send "build" "$title" "$message" "high" "hammer" "$actions"
}

# Scout notifications — new proposals (batch-friendly)
# Args: title, message
ntfy_scout() {
  local title="$1" message="$2"
  ntfy_send "scout" "$title" "$message" "default" "telescope"
}

# Ops notifications — deploy status, monitoring
# Args: title, message, [priority]
ntfy_ops() {
  local title="$1" message="$2" priority="${3:-default}"
  ntfy_send "ops" "$title" "$message" "$priority" "anchor"
}

# Digest — daily/weekly summaries
# Args: title, message
ntfy_digest() {
  local title="$1" message="$2"
  ntfy_send "digest" "$title" "$message" "low" "scroll"
}

# --- Action button helpers ---

# Build a "view" action (opens URL)
# Args: label, url
ntfy_action_view() {
  local label="$1" url="$2"
  echo "view, ${label}, ${url}"
}

# Build an "http" action (POST to URL) — for Gitea API calls from notification buttons
# Args: label, url, [body], [headers]
ntfy_action_http() {
  local label="$1" url="$2" body="${3:-}" headers="${4:-}"
  local action="http, ${label}, ${url}, method=POST"
  if [[ -n "$body" ]]; then
    action+=", body=${body}"
  fi
  if [[ -n "$headers" ]]; then
    action+=", headers=${headers}"
  fi
  echo "$action"
}

# --- Decision request ---

# Send a decision request with action buttons that post to Gitea
# This is the primary Captain interaction pattern
# Args: crew_member, project, issue_number, question, option1_label, option1_text, option2_label, option2_text
ntfy_decision() {
  local crew="$1" project="$2" issue="$3" question="$4"
  local opt1_label="$5" opt1_text="$6"
  local opt2_label="$7" opt2_text="$8"

  : "${GITEA_URL:?GITEA_URL must be set for decision notifications}"
  : "${GITEA_TOKEN:?GITEA_TOKEN must be set for decision notifications}"

  local comment_url="${GITEA_URL}/api/v1/repos/${SEAMONSTER_ORG:-seamonster}/${project}/issues/${issue}/comments"
  local auth_header="Authorization: token ${GITEA_TOKEN}"

  # Build action buttons
  local view_action
  view_action=$(ntfy_action_view "View Issue" "${GITEA_URL}/${SEAMONSTER_ORG:-seamonster}/${project}/issues/${issue}")

  local opt1_body
  opt1_body=$(jq -n --arg body "Decision: ${opt1_text}" '{body: $body}' | jq -c .)
  local opt1_action="http, ${opt1_label}, ${comment_url}, method=POST, headers.Authorization=token ${GITEA_TOKEN}, headers.Content-Type=application/json, body='${opt1_body}'"

  local opt2_body
  opt2_body=$(jq -n --arg body "Decision: ${opt2_text}" '{body: $body}' | jq -c .)
  local opt2_action="http, ${opt2_label}, ${comment_url}, method=POST, headers.Authorization=token ${GITEA_TOKEN}, headers.Content-Type=application/json, body='${opt2_body}'"

  local actions="${view_action}; ${opt1_action}; ${opt2_action}"

  ntfy_urgent \
    "${crew} needs a decision — ${project} #${issue}" \
    "$question" \
    "$actions"
}

# --- Health check ---

ntfy_health() {
  curl -fsSL -o /dev/null -w '%{http_code}' "${NTFY_URL}/v1/health" 2>/dev/null
}
