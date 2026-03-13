#!/usr/bin/env bash
set -euo pipefail

# Sea Monster session logger — Stop hook
# Logs basic session info (repo, branch, issue, timestamp) to a local file.
# Git issue commenting is handled by agents directly, not this hook.

LOG_DIR="${SEAMONSTER_LOG_DIR:-.seamonster/logs/sessions}"
TIMESTAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"

# Detect repo name from git remote or directory
REPO=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
  REPO="$(git remote get-url origin 2>/dev/null | sed 's|.*/||;s|\.git$||')" || true
fi
REPO="${REPO:-$(basename "$PWD")}"

# Detect branch
BRANCH=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
  BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || true
fi

# Detect issue number from branch name (issue-N pattern) or env
ISSUE="${ISSUE_NUMBER:-}"
if [[ -z "$ISSUE" && -n "$BRANCH" ]]; then
  if [[ "$BRANCH" =~ issue-([0-9]+) ]]; then
    ISSUE="${BASH_REMATCH[1]}"
  fi
fi

# Write log entry
mkdir -p "$LOG_DIR"
LOGFILE="${LOG_DIR}/${TIMESTAMP}_${REPO}.json"

cat > "$LOGFILE" <<ENTRY
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "repo": "${REPO}",
  "branch": "${BRANCH}",
  "issue": ${ISSUE:+$ISSUE}${ISSUE:-null},
  "cwd": "${PWD}"
}
ENTRY
