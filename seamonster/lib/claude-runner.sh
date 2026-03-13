#!/usr/bin/env bash
# claude-runner.sh — Claude Code invocation wrapper for Sea Monster
# Single point of control for how agents are spawned.
# Swap this file to change the AI engine (Pi, aider, etc.)

set -euo pipefail

# Resolve paths relative to the repo root (where this script lives under lib/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEAMONSTER_LOG_DIR="${SEAMONSTER_LOG_DIR:-${REPO_ROOT}/.seamonster/logs}"

# --- Configuration ---

# Max concurrent Claude sessions (respects subscription limits)
CLAUDE_MAX_CONCURRENT="${CLAUDE_MAX_CONCURRENT:-1}"

# Lock directory for concurrency control
CLAUDE_LOCK_DIR="${SEAMONSTER_LOCK_DIR:-/tmp/seamonster-locks}"

# --- Helpers ---

log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [claude-runner] $*" >&2
}

# --- Concurrency control ---

# Acquire a session slot. Blocks until one is available.
acquire_slot() {
  mkdir -p "$CLAUDE_LOCK_DIR"
  local slot
  for ((i = 0; i < CLAUDE_MAX_CONCURRENT; i++)); do
    slot="${CLAUDE_LOCK_DIR}/slot-${i}"
    if mkdir "$slot" 2>/dev/null; then
      echo "$slot"
      return 0
    fi
  done
  # No slot available — wait and retry
  log "All ${CLAUDE_MAX_CONCURRENT} slots occupied, waiting..."
  while true; do
    sleep 5
    for ((i = 0; i < CLAUDE_MAX_CONCURRENT; i++)); do
      slot="${CLAUDE_LOCK_DIR}/slot-${i}"
      if mkdir "$slot" 2>/dev/null; then
        echo "$slot"
        return 0
      fi
    done
  done
}

# Release a session slot
release_slot() {
  local slot="$1"
  rmdir "$slot" 2>/dev/null || true
}

# --- Session logging ---

# Create a log file path for this session
session_log_path() {
  local crew="$1" project="${2:-general}" issue="${3:-0}"
  mkdir -p "${SEAMONSTER_LOG_DIR}"
  echo "${SEAMONSTER_LOG_DIR}/${crew}_${project}_${issue}_$(date -u '+%Y%m%dT%H%M%SZ').log"
}

# --- Core invocation ---

# Run Claude in headless mode with a prompt.
# This is THE function that workflows call.
# Args: crew_member, project_dir, prompt
# Optional env: CLAUDE_MODEL, CLAUDE_ALLOWED_TOOLS
run_claude() {
  local crew="$1"
  local project_dir="$2"
  local prompt="$3"

  local log_file
  log_file=$(session_log_path "$crew" "$(basename "$project_dir")")

  log "Spawning ${crew} in ${project_dir}"

  local slot
  slot=$(acquire_slot)
  trap "release_slot '$slot'" EXIT

  local -a claude_args=(
    -p "$prompt"
    --dangerously-skip-permissions
  )

  # Allow callers to restrict tools
  if [[ -n "${CLAUDE_ALLOWED_TOOLS:-}" ]]; then
    claude_args+=(--allowedTools "${CLAUDE_ALLOWED_TOOLS}")
  fi

  local exit_code=0
  (
    cd "$project_dir"
    claude "${claude_args[@]}" 2>&1
  ) | tee "$log_file" || exit_code=$?

  release_slot "$slot"
  trap - EXIT

  if [[ $exit_code -ne 0 ]]; then
    log "ERROR: ${crew} exited with code ${exit_code}"
  else
    log "${crew} completed successfully"
  fi

  return $exit_code
}

# --- Convenience wrappers ---

# Run an agent with a git issue context.
# Fetches issue details and includes them in the prompt.
# Works with both Gitea and GitHub depending on which API script is available.
# Args: crew_member, owner, repo, issue_number, additional_prompt
run_agent_for_issue() {
  local crew="$1" owner="$2" repo="$3" issue="$4" prompt="$5"

  # Source the appropriate git API wrapper
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [[ -n "${GITEA_URL:-}" ]]; then
    # shellcheck source=./gitea-api.sh
    source "${lib_dir}/gitea-api.sh"
    local issue_json
    issue_json=$(gitea_get_issue "$owner" "$repo" "$issue")
  elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
    # shellcheck source=./github-api.sh
    source "${lib_dir}/github-api.sh"
    local issue_json
    issue_json=$(github_get_issue "$owner" "$repo" "$issue")
  else
    log "ERROR: Neither GITEA_URL nor GITHUB_TOKEN is set"
    return 1
  fi

  local issue_title issue_body
  issue_title=$(echo "$issue_json" | jq -r '.title')
  issue_body=$(echo "$issue_json" | jq -r '.body')

  local full_prompt
  full_prompt="You are the ${crew}.

## Issue #${issue}: ${issue_title}

${issue_body}

## Instructions

${prompt}

## Important
- Post progress updates as comments on issue #${issue}
- If you hit a blocker, add the 'needs-input' label and post your question with options
- Reference the issue number in all commits and PR descriptions"

  run_claude "$crew" "${REPO_ROOT}" "$full_prompt"
}

# Run an agent for a PR review (read-only).
# Args: crew_member, owner, repo, pr_number
run_reviewer_for_pr() {
  local crew="$1" owner="$2" repo="$3" pr="$4"

  # Restrict to read-only tools
  export CLAUDE_ALLOWED_TOOLS="Read,Glob,Grep,Bash(git diff*),Bash(git log*),Bash(git show*)"

  local prompt="You are the ${crew} (Reviewer). Review PR #${pr}.

## Instructions
- Read the PR diff carefully
- Check for: bugs, security issues, edge cases, code quality, test coverage
- Post your review
- Approve if the code meets standards, or request changes with specific feedback
- You are READ-ONLY — do not modify any files"

  run_claude "$crew" "${REPO_ROOT}" "$prompt"
  unset CLAUDE_ALLOWED_TOOLS
}
