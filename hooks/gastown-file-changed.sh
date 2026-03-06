#!/usr/bin/env bash
# Notify gastown when Claude Code writes/edits files.
# No-op when not inside a gastown rig or gt isn't installed.

command -v gt >/dev/null 2>&1 || exit 0

# Only fire if we're inside a gastown rig (gt status exits 0)
gt status >/dev/null 2>&1 || exit 0

event=$(cat)
file=$(echo "$event" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

[ -z "$file" ] && exit 0

gt hook fire file-changed "$file" 2>/dev/null || true
