#!/usr/bin/env bash
# ntfy-notify.sh — SubagentStop hook for Sea Monster
#
# Sends an ntfy notification when any agent session ends.
# Best effort: never fails the agent session, exits 0 always.
#
# Input: JSON on stdin from Claude Code hook system with fields:
#   - session_id, cwd, reason
#
# Config: reads ntfy_topic from .bridge/config.yml in the project directory.

set -uo pipefail

# Read hook input from stdin
hook_input=$(cat 2>/dev/null || echo '{}')

# Extract project directory — prefer CLAUDE_PROJECT_DIR, fall back to cwd from input
project_dir="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$project_dir" ]; then
  project_dir=$(echo "$hook_input" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"cwd"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')
fi

if [ -z "$project_dir" ]; then
  exit 0
fi

# Read ntfy topic from .bridge/config.yml
config_file="${project_dir}/.bridge/config.yml"
if [ ! -f "$config_file" ]; then
  exit 0
fi

# Parse ntfy_topic from YAML without yq — handles both quoted and unquoted values
ntfy_topic=$(grep -E '^ntfy_topic:' "$config_file" 2>/dev/null | head -1 | sed 's/^ntfy_topic:[[:space:]]*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//' | sed 's/[[:space:]]*$//')

if [ -z "$ntfy_topic" ]; then
  exit 0
fi

# Extract the stop reason from hook input for the notification body
reason=$(echo "$hook_input" | grep -o '"reason"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"reason"[[:space:]]*:[[:space:]]*"//' | sed 's/"$//')

# Build notification message
title="Sea Monster agent finished"
body="${reason:-Agent session completed}"

# Send ntfy notification — best effort, never fail
curl -s \
  -H "Title: ${title}" \
  -H "Tags: robot" \
  -d "${body}" \
  "${ntfy_topic}" 2>/dev/null || true

exit 0
