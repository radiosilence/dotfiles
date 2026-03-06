#!/usr/bin/env bash
# Update cmux workspace notification text with what Claude is working on.
# Triggered on UserPromptSubmit — reads prompt from hook JSON on stdin.

command -v cmux >/dev/null 2>&1 || exit 0

event=$(cat)
prompt=$(echo "$event" | jq -r '.prompt // empty' 2>/dev/null)

[ -z "$prompt" ] && exit 0

# Truncate to first 60 chars for sidebar readability
summary="${prompt:0:60}"
[ ${#prompt} -gt 60 ] && summary="${summary}…"

cmux notify --title "Working on" --body "$summary"
