#!/usr/bin/env bash
# Update cmux workspace notification text with what Claude is working on.
# Triggered on UserPromptSubmit — reads prompt from hook JSON on stdin.

command -v cmux >/dev/null 2>&1 || exit 0

event=$(cat)
prompt=$(echo "$event" | jq -r '.prompt // empty' 2>/dev/null)

[ -z "$prompt" ] && exit 0

# Get repo name from git, fall back to directory name
repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")

# Truncate prompt to fit sidebar with repo prefix
summary="${prompt:0:50}"
[ ${#prompt} -gt 50 ] && summary="${summary}…"

cmux notify --title "$repo" --body "$summary"
