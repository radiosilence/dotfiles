#!/usr/bin/env bash
# cmux UserPromptSubmit hook — update sidebar status + workspace title.
command -v cmux >/dev/null 2>&1 || exit 0

event=$(cat)
prompt=$(echo "$event" | jq -r '.prompt // empty' 2>/dev/null)

[ -z "$prompt" ] && exit 0

# Set status pill to "working"
cmux set-status claude "working" --icon sparkle --color "#34c759" 2>/dev/null

# Update notification text with truncated prompt
repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
summary="${prompt:0:50}"
[ ${#prompt} -gt 50 ] && summary="${summary}…"
cmux notify --title "$repo" --body "$summary" 2>/dev/null
