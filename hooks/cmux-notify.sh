#!/usr/bin/env bash
# cmux Stop hook — uses native claude-hook + set-status for sidebar pill.
command -v cmux >/dev/null 2>&1 || exit 0

event=$(cat)

# Use cmux's built-in claude-hook for proper notification handling
echo "$event" | cmux claude-hook stop 2>/dev/null

# Set sidebar status pill to "waiting"
cmux set-status claude "waiting" --icon sparkle --color "#ff9500" 2>/dev/null
