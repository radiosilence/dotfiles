#!/usr/bin/env bash
# cmux SessionStart hook — rename workspace to repo name and signal session start.
command -v cmux >/dev/null 2>&1 || exit 0

event=$(cat)

# Signal session start to cmux
echo "$event" | cmux claude-hook session-start 2>/dev/null

# Rename workspace to repo name
repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
cmux rename-workspace "$repo" 2>/dev/null

# Set initial status
cmux set-status claude "ready" --icon sparkle --color "#007aff" 2>/dev/null
