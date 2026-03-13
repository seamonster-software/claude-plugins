#!/usr/bin/env bash
# git-api.sh — Git platform API for Sea Monster agents (GitHub-only)
# Sources github-api.sh and provides sm_* wrapper functions.
#
# Authentication (in order):
#   GITHUB_TOKEN env var     -> GitHub API via curl
#   gh CLI authenticated     -> extracts token from gh, then uses curl
#
# All sm_* functions delegate directly to github_* functions.

set -euo pipefail

# --- Authentication ---

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    GITHUB_TOKEN="$(gh auth token 2>/dev/null)" || true
    if [[ -n "$GITHUB_TOKEN" ]]; then
      export GITHUB_TOKEN
    fi
  fi
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: No GitHub authentication found." >&2
  echo "Options:" >&2
  echo "  - Set GITHUB_TOKEN environment variable" >&2
  echo "  - Authenticate gh CLI: gh auth login" >&2
  exit 1
fi

# Source the GitHub API backend
# Works in both bash and zsh
_SM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
# shellcheck source=./github-api.sh
source "${_SM_LIB_DIR}/github-api.sh"

# --- Low-level API ---

sm_get() {
  github_get "$1"
}

sm_post() {
  github_post "$1" "${2:-{}}"
}

sm_patch() {
  github_patch "$1" "${2:-{}}"
}

sm_delete() {
  github_delete "$1"
}

# --- Issues ---

# Create an issue. Args: owner, repo, title, body, [labels_names_json]
sm_create_issue() {
  github_create_issue "$@"
}

# Get issue details. Args: owner, repo, issue_number
sm_get_issue() {
  github_get_issue "$1" "$2" "$3"
}

# Comment on an issue. Args: owner, repo, issue_number, body
sm_comment() {
  github_comment "$1" "$2" "$3" "$4"
}

# List issues (excludes PRs). Args: owner, repo, [state]
sm_list_issues() {
  local owner="$1" repo="$2" state="${3:-open}"
  github_get "/repos/${owner}/${repo}/issues?state=${state}&per_page=50" | \
    jq '[.[] | select(.pull_request == null)]'
}

# --- Labels ---

# Add labels by name. Args: owner, repo, issue_number, labels_names_json
sm_add_labels() {
  github_add_labels "$1" "$2" "$3" "$4"
}

# Remove a label by name. Args: owner, repo, issue_number, label_name
sm_remove_label() {
  github_remove_label "$1" "$2" "$3" "$4"
}

# Check if a label exists. Args: owner, repo, label_name
sm_get_label_id() {
  github_get_label_id "$1" "$2" "$3"
}

# --- Pull Requests ---

# Create a PR. Args: owner, repo, title, body, head_branch, [base_branch]
sm_create_pr() {
  github_create_pr "$@"
}

# Post a review comment. Args: owner, repo, pr_number, body
sm_review_pr() {
  github_review_pr "$1" "$2" "$3" "$4"
}

# Approve a PR. Args: owner, repo, pr_number, [body]
sm_approve_pr() {
  github_approve_pr "$@"
}

# Merge a PR. Args: owner, repo, pr_number, [merge_style]
sm_merge_pr() {
  github_merge_pr "$@"
}

# List PRs. Args: owner, repo, [state]
sm_list_prs() {
  local owner="$1" repo="$2" state="${3:-open}"
  github_get "/repos/${owner}/${repo}/pulls?state=${state}&per_page=50"
}

# --- Repos ---

# Create a repo in an org. Args: org, repo_name, [description]
sm_create_repo() {
  github_create_repo "$@"
}

# List repos in an org. Args: org
sm_list_repos() {
  github_list_repos "$1"
}

# --- Milestones ---

# Create a milestone. Args: owner, repo, title, [description], [due_date]
sm_create_milestone() {
  github_create_milestone "$@"
}

# --- Utility ---

# Check API health. Returns HTTP status code.
sm_health() {
  github_health
}
