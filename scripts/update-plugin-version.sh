#!/usr/bin/env bash
set -euo pipefail

# Update the version field in x/.claude-plugin/plugin.json
# Called by semantic-release via @semantic-release/exec during the prepare step.
#
# Usage: update-plugin-version.sh <new-version>

VERSION="${1:?Usage: update-plugin-version.sh <version>}"
PLUGIN_JSON="x/.claude-plugin/plugin.json"

if [[ ! -f "$PLUGIN_JSON" ]]; then
  echo "ERROR: $PLUGIN_JSON not found" >&2
  exit 1
fi

# Use a temporary file for atomic update
TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

# Update the version field using jq
jq --arg v "$VERSION" '.version = $v' "$PLUGIN_JSON" > "$TMP_FILE"
mv "$TMP_FILE" "$PLUGIN_JSON"

echo "Updated $PLUGIN_JSON version to $VERSION"
