#!/usr/bin/env bash
# git-api.sh — Unified git platform API for Sea Monster agents
# Sources the correct backend (Gitea or GitHub) based on environment variables
# or CLI tools (gh/tea).
# All sm_* functions work identically regardless of platform.
#
# Platform detection (in order):
#   GITEA_URL set              → Gitea backend via curl (requires GITEA_TOKEN)
#   GITHUB_TOKEN set           → GitHub backend via curl
#   gh CLI authenticated       → GitHub backend via gh api
#   tea CLI authenticated      → Gitea backend via tea
#
# Label normalization:
#   All sm_* label functions accept label NAMES (strings).
#   Gitea ID resolution is handled internally — callers never deal with IDs.

set -euo pipefail

# --- Platform Detection ---

SM_API_MODE=""  # "token" (curl + env var) or "cli" (gh/tea)

if [[ -n "${GITEA_URL:-}" ]]; then
  SM_PLATFORM="gitea"
  SM_API_MODE="token"
elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
  SM_PLATFORM="github"
  SM_API_MODE="token"
elif command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
  SM_PLATFORM="github"
  SM_API_MODE="cli"
  # Extract token from gh for curl-based backends
  GITHUB_TOKEN="$(gh auth token 2>/dev/null)" || true
  if [[ -n "$GITHUB_TOKEN" ]]; then
    SM_API_MODE="token"
    export GITHUB_TOKEN
  fi
elif command -v tea &>/dev/null && tea login list 2>/dev/null | grep -q .; then
  SM_PLATFORM="gitea"
  SM_API_MODE="cli"
  GITEA_URL="$(tea login list --output simple 2>/dev/null | head -1 | awk '{print $2}')" || true
  GITEA_TOKEN="$(tea login list --output simple 2>/dev/null | head -1 | awk '{print $3}')" || true
  if [[ -n "$GITEA_URL" && -n "$GITEA_TOKEN" ]]; then
    SM_API_MODE="token"
    export GITEA_URL GITEA_TOKEN
  fi
else
  echo "ERROR: No git platform configured." >&2
  echo "Options:" >&2
  echo "  - Set GITHUB_TOKEN for GitHub" >&2
  echo "  - Set GITEA_URL + GITEA_TOKEN for Gitea" >&2
  echo "  - Authenticate gh CLI: gh auth login" >&2
  echo "  - Authenticate tea CLI: tea login add" >&2
  exit 1
fi
export SM_PLATFORM SM_API_MODE

# Source the platform-specific backend
# Works in both bash and zsh
_SM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
# shellcheck source=./gitea-api.sh
# shellcheck source=./github-api.sh
source "${_SM_LIB_DIR}/${SM_PLATFORM}-api.sh"

# --- Low-level API ---
# Pass-through to the platform backend with automatic pagination normalization.
# Gitea uses limit=N, GitHub uses per_page=N. Gitea's type=issues param is
# stripped on GitHub (not supported).

sm_get() {
  local endpoint="$1"
  case "$SM_PLATFORM" in
    github)
      endpoint="${endpoint//limit=/per_page=}"
      endpoint="${endpoint//&type=issues/}"
      endpoint="${endpoint//\?type=issues&/?}"
      endpoint="${endpoint//\?type=issues/}"
      ;;
    gitea)
      endpoint="${endpoint//per_page=/limit=}"
      ;;
  esac
  "${SM_PLATFORM}_get" "$endpoint"
}

sm_post() {
  "${SM_PLATFORM}_post" "$1" "${2:-{}}"
}

sm_patch() {
  "${SM_PLATFORM}_patch" "$1" "${2:-{}}"
}

sm_delete() {
  "${SM_PLATFORM}_delete" "$1"
}

# --- Issues ---

# Create an issue. Args: owner, repo, title, body, [labels_names_json]
# Labels are always names: '["build-ready", "team/build"]'
sm_create_issue() {
  local owner="$1" repo="$2" title="$3" body="$4"
  local labels="${5:-[]}"

  case "$SM_PLATFORM" in
    gitea)
      if [[ "$labels" != "[]" ]]; then
        local all_labels label_ids
        all_labels=$(gitea_get "/repos/${owner}/${repo}/labels?limit=50")
        label_ids=$(echo "$all_labels" | jq --argjson names "$labels" \
          '[.[] | select(.name as $n | $names | index($n)) | .id]')
        gitea_create_issue "$owner" "$repo" "$title" "$body" "$label_ids"
      else
        gitea_create_issue "$owner" "$repo" "$title" "$body"
      fi
      ;;
    github)
      github_create_issue "$owner" "$repo" "$title" "$body" "$labels"
      ;;
  esac
}

# Get issue details. Args: owner, repo, issue_number
sm_get_issue() {
  "${SM_PLATFORM}_get_issue" "$1" "$2" "$3"
}

# Comment on an issue. Args: owner, repo, issue_number, body
sm_comment() {
  "${SM_PLATFORM}_comment" "$1" "$2" "$3" "$4"
}

# List issues (excludes PRs). Args: owner, repo, [state]
sm_list_issues() {
  local owner="$1" repo="$2" state="${3:-open}"
  case "$SM_PLATFORM" in
    gitea)
      gitea_get "/repos/${owner}/${repo}/issues?state=${state}&limit=50&type=issues"
      ;;
    github)
      github_get "/repos/${owner}/${repo}/issues?state=${state}&per_page=50" | \
        jq '[.[] | select(.pull_request == null)]'
      ;;
  esac
}

# --- Labels ---
# All label functions use label NAMES. Gitea ID resolution is handled internally.

# Add labels by name. Args: owner, repo, issue_number, labels_names_json
# Example: sm_add_labels "org" "repo" "47" '["build-ready", "priority/p1"]'
sm_add_labels() {
  local owner="$1" repo="$2" issue="$3" labels="$4"

  case "$SM_PLATFORM" in
    gitea)
      local all_labels label_ids
      all_labels=$(gitea_get "/repos/${owner}/${repo}/labels?limit=50")
      label_ids=$(echo "$all_labels" | jq --argjson names "$labels" \
        '[.[] | select(.name as $n | $names | index($n)) | .id]')
      gitea_add_labels "$owner" "$repo" "$issue" "$label_ids"
      ;;
    github)
      github_add_labels "$owner" "$repo" "$issue" "$labels"
      ;;
  esac
}

# Remove a label by name. Args: owner, repo, issue_number, label_name
sm_remove_label() {
  local owner="$1" repo="$2" issue="$3" label_name="$4"

  case "$SM_PLATFORM" in
    gitea)
      local label_id
      label_id=$(gitea_get_label_id "$owner" "$repo" "$label_name")
      if [[ -n "$label_id" ]]; then
        gitea_remove_label "$owner" "$repo" "$issue" "$label_id"
      fi
      ;;
    github)
      github_remove_label "$owner" "$repo" "$issue" "$label_name"
      ;;
  esac
}

# Check if a label exists. Args: owner, repo, label_name
# Returns the platform identifier (ID for Gitea, name for GitHub) or empty.
sm_get_label_id() {
  "${SM_PLATFORM}_get_label_id" "$1" "$2" "$3"
}

# --- Pull Requests ---

# Create a PR. Args: owner, repo, title, body, head_branch, [base_branch]
sm_create_pr() {
  "${SM_PLATFORM}_create_pr" "$@"
}

# Post a review comment. Args: owner, repo, pr_number, body
sm_review_pr() {
  "${SM_PLATFORM}_review_pr" "$1" "$2" "$3" "$4"
}

# Approve a PR. Args: owner, repo, pr_number, [body]
sm_approve_pr() {
  "${SM_PLATFORM}_approve_pr" "$@"
}

# Merge a PR. Args: owner, repo, pr_number, [merge_style]
sm_merge_pr() {
  "${SM_PLATFORM}_merge_pr" "$@"
}

# List PRs. Args: owner, repo, [state]
sm_list_prs() {
  local owner="$1" repo="$2" state="${3:-open}"
  case "$SM_PLATFORM" in
    gitea)  gitea_get "/repos/${owner}/${repo}/pulls?state=${state}&limit=50" ;;
    github) github_get "/repos/${owner}/${repo}/pulls?state=${state}&per_page=50" ;;
  esac
}

# --- Repos ---

# Create a repo in an org. Args: org, repo_name, [description]
sm_create_repo() {
  "${SM_PLATFORM}_create_repo" "$@"
}

# List repos in an org. Args: org
sm_list_repos() {
  local org="$1"
  case "$SM_PLATFORM" in
    gitea)  gitea_get "/orgs/${org}/repos?limit=50" ;;
    github) github_list_repos "$org" ;;
  esac
}

# --- Milestones ---

# Create a milestone. Args: owner, repo, title, [description], [due_date]
sm_create_milestone() {
  "${SM_PLATFORM}_create_milestone" "$@"
}

# --- Utility ---

# Check API health. Returns HTTP status code.
sm_health() {
  "${SM_PLATFORM}_health"
}
