#!/usr/bin/env bash
# cmux notification hook for Claude Code
# Fires cmux notify on Stop events so the workspace sidebar shows agent status.
#
# Add to ~/.claude/settings.json:
#   "hooks": {
#     "Stop": [{ "type": "command", "command": "~/.dotfiles/hooks/cmux-notify.sh" }]
#   }

command -v cmux >/dev/null 2>&1 || exit 0

# Parse the hook event JSON from stdin
event=$(cat)
tool=$(echo "$event" | jq -r '.tool_name // empty' 2>/dev/null)
stop_reason=$(echo "$event" | jq -r '.stop_reason // empty' 2>/dev/null)

if [ -n "$stop_reason" ]; then
  cmux notify --title "Claude Code" --body "Waiting for input"
elif [ "$tool" = "Task" ]; then
  cmux notify --title "Claude Code" --body "Agent task finished"
fi
